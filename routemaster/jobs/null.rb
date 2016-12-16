require 'routemaster/mixins/log'

module Routemaster
  module Jobs
    class Null
      include Mixins::Log

      def call(*args)
        _log.debug { args.inspect }
      end
    end
  end
end

