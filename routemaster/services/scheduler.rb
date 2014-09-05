require 'rufus-scheduler'

scheduler = Rufus::Scheduler.new

scheduler.every '1m' do
  return unless ENV.fetch('METRIC_COLLECTION_SERVICE')

  tags = [
    "env:#{ENV['RACK_ENV']}",
    'app:routemaster'
  ]

  Routemaster::Mixins::DeliverMetric.deliver(
    'subscription.queue.size',
    subscription.queue.message_count,
    tags
  )

  Routemaster::Mixins::DeliverMetric.deliver(
    'subscription.queue.staleness',
    subscription.queue.age_of_oldest_message,
    tags
  )
end
