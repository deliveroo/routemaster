require 'routemaster/models'
require 'routemaster/mixins/assert'

class Routemaster::Models::User < String
  include Routemaster::Mixins::Assert

  def initialize(str)
    _assert str.kind_of?(String)
    _assert (str =~ /[a-z0-9:_-]{1,64}/)
    super
  end
end

