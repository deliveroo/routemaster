if ENV['AUTOSCALE_WITH'] == 'hirefire'
  require 'routemaster/models/subscription'

  HireFire::Resource.configure do |config|
    config.dyno(:worker) do
      Routemaster::Models::Subscription.reduce(0) do |sum, sub|
        sum += sub.queue.message_count
      end
    end
  end
end
