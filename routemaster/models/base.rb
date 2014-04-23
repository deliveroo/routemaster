require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/bunny'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log'

class Routemaster::Models::Base
  include Routemaster::Mixins::Redis
  include Routemaster::Mixins::Bunny
  include Routemaster::Mixins::Assert
  include Routemaster::Mixins::Log
end
