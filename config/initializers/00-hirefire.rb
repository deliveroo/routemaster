if ENV['AUTOSCALE_WITH'] == 'hirefire'
  require 'routemaster/models/subscription'

  HireFire::Resource.configure do |config|
    config.dyno(:watch) do
      Routemaster::Models::Subscription.reduce(0) do |sum, sub|
        sum += sub.queue.length
      end
    end
  end
end
