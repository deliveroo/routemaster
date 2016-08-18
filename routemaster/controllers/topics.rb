require 'routemaster/controllers'
require 'routemaster/models/topic'
require 'routemaster/services/ingest'
require 'sinatra'
require 'json'

module Routemaster
  module Controllers
    class Topics < Sinatra::Base
      get '/topics' do
        content_type :json
        Routemaster::Models::Topic.all.map do |topic|
          {
            name: topic.name,
            publisher: topic.publisher,
            events: topic.get_count
          }
        end.to_json
      end

      post '/topics/:name' do

        begin
          topic = Routemaster::Models::Topic.new(
            name:       params['name'],
            publisher:  request.env['REMOTE_USER']
          )
        rescue ArgumentError
          halt 400, 'bad topic'
        rescue Routemaster::Models::Topic::TopicClaimedError
          halt 403, 'topic claimed'
        end

        begin
          event_data = JSON.parse(request.body.read)
        rescue JSON::ParserError
          halt 400, 'misformated JSON'
        end

        if !event_data.has_key?('type') || !event_data.has_key?('url')
          halt 400, 'bad event'
        end

        begin
          event = Routemaster::Models::Event.new(
            topic: params['name'],
            type:  event_data.fetch('type'),
            url:   event_data.fetch('url'),
            timestamp: event_data.fetch('timestamp', nil)
          )
        rescue ArgumentError
          halt 400, 'bad event'
        end

        Services::Ingest.new(topic: topic, event: event).call

        halt :ok
      end
    end
  end
end
