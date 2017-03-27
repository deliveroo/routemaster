require 'routemaster/controllers'
require 'routemaster/controllers/parser'
require 'routemaster/models/topic'
require 'routemaster/services/ingest'
require 'routemaster/mixins/log'
require 'sinatra'
require 'json'

module Routemaster
  module Controllers
    class Topics < Sinatra::Base
      include Mixins::Log
      register Parser

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

      post '/topics/:name', parse: :json do
        begin
          topic = Routemaster::Models::Topic.find_or_create!(
            name:       params['name'],
            publisher:  request.env['REMOTE_USER']
          )
        rescue ArgumentError
          halt 400, 'bad topic'
        rescue Routemaster::Models::Topic::TopicClaimedError
          halt 403, 'topic claimed'
        end

        if !data.has_key?('type') || !data.has_key?('url')
          halt 400, 'bad event'
        end

        begin
          event = Routemaster::Models::Event.new(
            topic: params['name'],
            type:  data.fetch('type'),
            url:   data.fetch('url'),
            timestamp: data['timestamp'] || Routemaster.now
          )
        rescue ArgumentError => e
          _log.warn { "failed to parse event" }
          _log_exception(e)
          halt 400, 'bad event'
        end

        Services::Ingest.new(topic: topic, event: event, queue: Routemaster.batch_queue).call

        halt :ok
      end

      delete '/topics/:name' do
        topic = Routemaster::Models::Topic.find(params[:name])
        halt 404 if topic.nil?
        topic.destroy
        halt 204
      end
    end
  end
end
