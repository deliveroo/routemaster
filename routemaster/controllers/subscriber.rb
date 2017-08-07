require 'routemaster/controllers/base'
require 'routemaster/models/topic'
require 'routemaster/models/subscriber'
require 'routemaster/models/batch'
require 'routemaster/services/update_subscriber_topics'

module Routemaster
  module Controllers
    class Subscriber < Base
      VALID_KEYS = %w(topics callback uuid max timeout)

      post %r{^/(subscription|subscriber)$}, auth: :client, parse: :json do
        $stderr.puts data.inspect
        if (data.keys - VALID_KEYS).any?
          halt 400, 'bad data in payload'
        end

        unless data['topics'].kind_of?(Array)
          halt 400, 'need an array of topics'
        end

        topics = data['topics'].map do |name|
          Models::Topic.find_or_create!(name: name)
        end
        halt 404 unless topics.all?

        begin
          sub = Models::Subscriber.new(name: current_token)
          sub.callback   = data['callback']
          sub.uuid       = data['uuid']
          sub.timeout    = data['timeout'] if data['timeout']
          sub.max_events = data['max']     if data['max']
          sub.save
        rescue ArgumentError => e
          halt 400, e.message
        end

        Services::UpdateSubscriberTopics.new(
          topics:     topics,
          subscriber: sub,
        ).call

        halt 204
      end

      delete '/subscriber', auth: %i[root client] do
        _load_subscriber.destroy
        halt 204
      end

      delete '/subscriber/topics/:name', auth: %i[root client] do
        subscriber = _load_subscriber
        topic = Models::Topic.find(params['name'])
        if topic.nil?
          halt 404, 'topic not found'
        end

        subscription = Models::Subscription.find(topic: topic, subscriber: subscriber)
        if subscription.nil?
          halt 404, 'not subscribed'
        end

        subscription.destroy
        halt 204
      end

      # GET /subscribers
      # [
      #   {
      #     subscriber: <username>,
      #     callback:   <url>,
      #     topics:     [<name>, ...],
      #     events: {
      #       sent:       <sent_count>,
      #       queued:     <queue_size>,
      #       oldest:     <staleness>,
      #     }
      #   }, ...
      # ]

      get %r{^/(subscriptions|subscribers)$}, auth: %i[root client] do
        content_type :json
        gauges = Models::Batch.gauges
        payload = Models::Subscriber.map do |subscriber|
          {
            subscriber: subscriber.name,
            callback: subscriber.callback,
            topics: subscriber.topics.map(&:name),
            events: {
              sent:   nil,
              queued: gauges[:events][subscriber.name],
              oldest: nil,
            }
          }
        end
        payload.to_json
      end

      private

      def _load_subscriber
        sub = Models::Subscriber.find(current_token)
        sub or halt 404, 'subscriber not found'
      end
    end
  end
end
