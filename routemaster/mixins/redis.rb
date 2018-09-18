require 'routemaster/mixins'
require 'connection_pool'
require 'redis'
require 'core_ext/env'

module Routemaster
  module Mixins
    module Redis
      REDIS_URLS = [].tap { |array|
        redis_urls_string = ENV['ROUTEMASTER_REDIS_URLS'] || ENV['ROUTEMASTER_REDIS_URL']
        redis_urls_string.split(',').each do |rus|
          ru = rus.strip.freeze
          array << ru unless ru.empty?
        end
      }.freeze
      MAX_REDIS_URLS_INDEX = REDIS_URLS.size - 1
      REDIS_URL_INDEX_KEY = :redis_url_index

      def self.included(by)
        by.extend(self)
        by.send(:protected, :_redis)
      end

      def _redis
        _all_redis[_move_and_return_redis_index_pointer]
      end

      def _move_and_return_redis_index_pointer
        if (MAX_REDIS_URLS_INDEX == 0) || (Thread.current[REDIS_URL_INDEX_KEY] >= MAX_REDIS_URLS_INDEX)
          Thread.current[REDIS_URL_INDEX_KEY] = 0
        else
          Thread.current[REDIS_URL_INDEX_KEY] += 1
        end
      end

      def _all_redis
        @@_all_redis ||= {}.tap do |hash|
          (0..MAX_REDIS_URLS_INDEX).each do |index|
            hash[index] = ConnectionPool.wrap(size: Routemaster.config[:redis_pool_size], timeout: 2) do
              ::Redis.new(url: redis_urls[index])
            end
          end
        end
      end

      def _redis_lua_sha(script_name)
        @@_redis_lua_sha ||= {}
        sha = @@_redis_lua_sha[script_name]
        return sha unless sha.nil?

        file_path = File.expand_path("../../lua/#{script_name}.lua", __FILE__)
        file_data = File.read(file_path)
        _all_redis.map { |redis|
          @@_redis_lua_sha[script_name] = redis.script('load', file_data)
        }.last
      end

      def _redis_lua_run(script_name, keys: nil, argv: nil)
        sha = _redis_lua_sha(script_name)
        _all_redis.map { |redis|
          redis.evalsha(sha, keys: keys, argv: argv)
        }.last
      rescue ::Redis::CommandError => e
        raise unless /NOSCRIPT/ =~ e.message
        @@_redis_lua_sha.delete(script_name)
        retry
      end
    end
  end
end
