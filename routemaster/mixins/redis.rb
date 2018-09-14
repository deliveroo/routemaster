require 'routemaster/mixins'
require 'connection_pool'
require 'redis'
require 'core_ext/env'

module Routemaster
  module Mixins
    module Redis
      def self.included(by)
        by.extend(self)
        by.send(:protected, :_redis)
      end

      def _redis
        @@_redis ||=
        ConnectionPool.wrap(size: Routemaster.config[:redis_pool_size], timeout: 2) do
          key = ENV['REDIS_ENV_KEY']
          key = 'ROUTEMASTER_REDIS_URL' unless (key && ENV.key?(key))
          ::Redis.new(url: ENV.fetch(key))
        end
      end

      def _redis_lua_sha(script_name)
        @@_redis_lua_sha ||= {}
        sha = @@_redis_lua_sha[script_name] and return sha

        path = File.expand_path("../../lua/#{script_name}.lua", __FILE__)
        sha = _redis.script('load', File.read(path))
        @@_redis_lua_sha[script_name] = sha
      end

      def _redis_lua_run(script_name, keys:nil, argv:nil)
        sha = _redis_lua_sha(script_name)
        _redis.evalsha(sha, keys: keys, argv: argv)
      rescue ::Redis::CommandError => e
        raise unless /NOSCRIPT/ =~ e.message
        @@_redis_lua_sha.delete script_name
        retry
      end
    end
  end
end
