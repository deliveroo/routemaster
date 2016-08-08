require 'routemaster/models'
require 'routemaster/mixins/assert'
require 'uri'

module Routemaster
  module Models
    class CallbackURL < String
      include Mixins::Assert

      def initialize(url)
        parsed_url = URI.parse(url)
        _assert (parsed_url.scheme == 'https'), 'URL is not HTTPS'
        _assert parsed_url.query.nil?, 'URL has query string'
        super
      end
    end
  end
end
