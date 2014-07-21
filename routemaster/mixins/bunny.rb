require 'routemaster/mixins'
require 'routemaster/models/bunny_channel'

module Routemaster
  module Mixins
    module Bunny
      def self.included(by)
        by.extend(self)
        by.send(:protected, :bunny)
      end

      def bunny
        @_bunny_channel ||= Models::BunnyChannel.new
      end

      # def _bunny_disconnect
      #   if @_bunny_channel
      #     @_bunny_channel.close
      #     @_bunny_channel = nil
      #   end
      # end

      def _bunny_name(string)
        "routemaster.#{ENV.fetch('RACK_ENV', 'development')}.#{string}"
      end

      # private

      # Lock = Mutex.new

      # def _bunny_connection
      #   Lock.synchronize do
      #     @@_bunny_connection ||= Bunny.new(ENV['ROUTEMASTER_AMQP_URL']).start
      #   end
      # end

    end
  end
end
