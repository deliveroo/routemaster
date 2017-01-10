require 'routemaster/controllers'
require 'routemaster/models/topic'
require 'routemaster/models/subscriber'
require 'routemaster/services/update_subscriber_topics'
require 'routemaster/controllers/parser'
require 'sinatra/base'

module Routemaster
  module Controllers
    class Subscriber < Sinatra::Base
      register Parser

      VALID_KEYS = %w(topics callback uuid max timeout)

      post %r{^/(subscription|subscriber)$}, parse: :json do
        if (data.keys - VALID_KEYS).any?
          halt 400, 'bad data in payload'
        end

        unless data['topics'].kind_of?(Array)
          halt 400, 'need an array of topics'
        end

        topics = data['topics'].map do |name|
          Models::Topic.find(name) ||
          Models::Topic.new(name: name, publisher: nil)
        end
        halt 404 unless topics.all?

        begin
          sub = Models::Subscriber.new(name: request.env['REMOTE_USER'])
          sub.callback   = data['callback']
          sub.uuid       = data['uuid']
          sub.timeout    = data['timeout'] if data['timeout']
          sub.max_events = data['max']     if data['max']
        rescue ArgumentError => e
          halt 400, e.message
        end

        Services::UpdateSubscriberTopics.new(
          topics:     topics,
          subscriber: sub,
        ).call

        halt 204
      end

      delete '/subscriber' do
        _load_subscriber.destroy
        halt 204
      end

      delete '/subscriber/topics/:name' do
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

      get %r{^/(subscriptions|subscribers)$} do
        content_type :json
        payload = Models::Subscriber.map do |subscriber|
          {
            subscriber: subscriber.name,
            uuid: subscriber.uuid,
            callback: subscriber.callback,
            topics: subscriber.topics.map(&:name),
            events: {
              sent: subscriber.all_topics_count,
              queued: subscriber.queue.length,
              oldest: subscriber.queue.staleness,
            }
          }
        end
        payload.to_json
      end

      private

      def _load_subscriber
        sub = Models::Subscriber.find(request.env['REMOTE_USER'])
        sub or halt 404, 'subscriber not found'
      end
    end
  end
end
