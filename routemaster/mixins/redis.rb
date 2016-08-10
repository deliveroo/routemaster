require 'routemaster/mixins'
require 'redis'
require 'redis-namespace'
require 'redis/connection/hiredis'

module Routemaster
  module Mixins
    module Redis
      def self.included(by)
        by.extend(self)
        by.send(:protected, :_redis)
      end

      def _redis
        @@_redis ||= ::Redis::Namespace.new(
          ENV.fetch('ROUTEMASTER_REDIS_PREFIX'),
          redis: ::Redis.new(url: ENV['ROUTEMASTER_REDIS_URL']))
      end

      def _redis_prefix
        @@_redis_prefix ||= ENV.fetch('ROUTEMASTER_REDIS_PREFIX')
      end

      def _lua_sha(script_name)
        @@_lua_sha ||= {}
        sha = @@_lua_sha[script_name] and return sha

        path = File.expand_path("../../lua/#{script_name}.lua", __FILE__)
        sha = _redis.script('load', File.read(path))
        @@_lua_sha[script_name] = sha
      end

      def _lua_run(script_name, keys:nil, argv:nil)
        sha = _lua_sha(script_name)
        _redis.evalsha(sha, keys: keys, argv: argv)
      end
    end
  end
end
