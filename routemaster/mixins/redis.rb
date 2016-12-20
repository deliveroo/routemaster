require 'routemaster/mixins'
require 'connection_pool'
require 'redis'

module Routemaster
  module Mixins
    module Redis
      def self.included(by)
        by.extend(self)
        by.send(:protected, :_redis)
      end

      def _redis
        # FIXME: pool size should be defined differently for workers (with
        # multiple blocking threads) and the web frontend (which can share fewer
        # connections)
        @@_redis ||=
          ConnectionPool.wrap(size: Routemaster.config[:redis_pool_size], timeout: 2) do
          ::Redis.new(url: ENV.fetch('ROUTEMASTER_REDIS_URL'))
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
      end
    end
  end
end
