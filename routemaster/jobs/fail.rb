require 'routemaster/mixins/log'

module Routemaster
  module Jobs
    class Fail
      include Mixins::Log

      def call(*args)
        raise 'failing job'
      end
    end
  end
end


