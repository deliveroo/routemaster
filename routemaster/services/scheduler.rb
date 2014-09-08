require 'rufus-scheduler'
require 'routemaster/services/scheduler'
require 'routemaster/services/deliver_metric'

include Routemaster::Services::DeliverMetric

scheduler = Rufus::Scheduler.new

scheduler.every '1s' do

  puts "***** Scheduler Fired!! *****"

  tags = [
    "env:#{ENV['RACK_ENV']}",
    'app:routemaster'
  ]

  Routemaster::Models::Subscription.each do |subscription|
    Routemaster::Services::DeliverMetric.deliver(
      'subscription.queue.size',
      subscription.queue.message_count,
      tags
    )

    Routemaster::Services::DeliverMetric.deliver(
      'subscription.queue.staleness',
      subscription.age_of_oldest_message,
      tags
    )
  end
end
