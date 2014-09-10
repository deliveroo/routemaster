require 'routemaster/models/subscription'

HireFire::Resource.configure do |config|
  config.dyno(:worker) do
    Routemaster::Models::Subscription.reduce(0) do |sum, sub|
      sum += sub.all_topics_count
    end
  end
end
