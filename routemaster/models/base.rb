require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log'

module Routemaster
  module Models
    class Base
      include Routemaster::Mixins::Redis
      include Routemaster::Mixins::Assert
      include Routemaster::Mixins::Log
    end
  end
end
