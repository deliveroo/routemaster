require 'routemaster/models'
require 'routemaster/mixins/connection'

class Routemaster::Models::Base
  include Routemaster::Mixins::Connection
end
