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
        # TODO: log this
        halt 400 if (data.keys - VALID_KEYS).any?
        halt 400 unless data['topics'].kind_of?(Array)

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
          # TODO: log this.
          halt 400
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
        sub = _load_subscriber
        topic = Models::Topic.find(params['name'])
        if topic.nil?
          halt 404, 'topic not found'
        end
        unless topic.subscribers.include?(sub)
          halt 404, 'not subscribed'
        end
        topic.subscribers.remove(sub)
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
