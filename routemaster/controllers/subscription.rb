require 'routemaster/controllers'
require 'routemaster/models/topic'
require 'routemaster/models/subscription'
require 'sinatra'

module Routemaster
  module Controllers
    class Subscription < Sinatra::Base
      VALID_KEYS = %w(topics callback uuid max timeout)

      post '/subscription' do
        begin
          data = JSON.parse(request.body.read)
        rescue JSON::ParserError => e
          # TODO: log this.
          halt 400
        end

        # TODO: log this
        halt 400 if (data.keys - VALID_KEYS).any?
        halt 400 unless data['topics'].kind_of?(Array)

        topics = data['topics'].map do |name|
          Models::Topic.find(name) ||
          Models::Topic.new(name: name, publisher: nil)
        end
        halt 404 unless topics.all?

        begin
          sub = Models::Subscription.new(subscriber: request.env['REMOTE_USER'])
          sub.callback   = data['callback']
          sub.uuid       = data['uuid']
          sub.timeout    = data['timeout'] if data['timeout']
          sub.max_events = data['max']     if data['max']
        rescue ArgumentError => e
          # TODO: log this.
          halt 400
        end

        topics.each do |topic|
          topic.subscribers.add(sub)
        end

        halt 204
      end

      # GET /subscriptions
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

      get '/subscriptions' do
        content_type :json
        payload = Models::Subscription.map do |subscription|
          {
            subscriber: subscription.subscriber,
            callback: subscription.callback,
            topics: subscription.topics.map(&:name),
            events: {
              sent: subscription.all_topics_count,
              queued: subscription.queue.message_count,
              oldest: subscription.age_of_oldest_message
            }
          }
        end
        payload.to_json
      end
    end
  end
end
