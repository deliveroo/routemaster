require 'rufus-scheduler'
require 'routemaster/services/scheduler'
require 'routemaster/services/deliver_metric'

include Routemaster::Services::DeliverMetric

if ENV.fetch('SCHEDULER_ENABLED', false)
  puts "SCHEDULER_ENABLED"
  scheduler = Rufus::Scheduler.new

  scheduler.every '5s' do
    tags = [
      "env:#{ENV['RACK_ENV']}",
      'app:routemaster'
    ]

    Routemaster::Models::Subscription.each do |subscription|
      Routemaster::Services::DeliverMetric.deliver(
        'subscription.queue.size',
        subscription.queue.message_count,
        tags + ["subscription:#{subscription.subscriber}"]
      )

      Routemaster::Services::DeliverMetric.deliver(
        'subscription.queue.staleness',
        subscription.age_of_oldest_message,
        tags + ["subscription:#{subscription.subscriber}"]
      )
    end
  end

else
  puts "SCHEDULER_DISABLED"
end
