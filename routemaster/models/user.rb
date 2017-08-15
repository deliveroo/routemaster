require 'routemaster/models'
require 'routemaster/mixins/assert'

module Routemaster
  module Models
    class User < String
      include Mixins::Assert

      def initialize(str)
        _assert str.kind_of?(String)
        _assert(str =~ /[a-z0-9:_-]{1,64}/)
        super
      end
    end
  end
end
