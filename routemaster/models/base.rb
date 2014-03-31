require 'routemaster/models'
require 'routemaster/mixins/connection'
require 'routemaster/mixins/assert'

class Routemaster::Models::Base
  include Routemaster::Mixins::Connection
  include Routemaster::Mixins::Assert
end
