require 'singleton'
require 'routemaster/services'

module Routemaster::Services::MetricsCollectors
  class Datadog

    def initialize
      require 'dogapi'

      api_key = ENV.fetch('DATADOG_API_KEY')
      @dog ||= Dogapi::Client.new(api_key)
    rescue KeyError
        abort 'Please install and configure datadog (or equivalent service) first!'
    end

    def perform(name, value, tags = [])
      all_tags = ["environment:#{ENV['RACK_ENV']}"] << tags
      @dog.emit_point(name, value, tags: all_tags)
    end

  end
end
