require 'routemaster/mixins'

begin
  require "routemaster/services/metrics_collectors/#{ENV.fetch('METRIC_COLLECTION_SERVICE', 'print')}"
rescue LoadError
  abort "Please install and configure metrics collection service first!"
end

module Routemaster::Mixins::DeliverMetric

  protected

  def deliver(name, value, tags = [])
    # send the exception message to your choice of service!
    service = ENV.fetch('METRIC_COLLECTION_SERVICE', 'print').camelize
    Routemaster::Services::MetricsCollectors.const_get(service)
      .instance.perform(name, value, tags)
  end

end
