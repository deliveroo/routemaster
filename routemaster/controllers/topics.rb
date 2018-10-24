require 'routemaster/controllers/base'
require 'routemaster/models/topic'
require 'routemaster/services/ingest'
require 'routemaster/services/kafka_publisher'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'json'

module Routemaster
  module Controllers
    class Topics < Base
      include Mixins::Log
      include Mixins::LogException

      register Parser

      get '/topics', auth: %i[client root] do
        content_type :json
        Routemaster::Models::Topic.all.map do |topic|
          {
            name: topic.name,
            publisher: topic.publisher,
            events: topic.get_count
          }
        end.to_json
      end

      post '/topics/:name', auth: :client, parse: :json do
        begin
          topic = Routemaster::Models::Topic.find_or_create!(
            name:       params['name'],
            publisher:  current_token
          )
        rescue ArgumentError
          halt 400, 'bad topic'
        rescue Routemaster::Models::Topic::TopicClaimedError
          halt 403, 'topic claimed'
        end

        if !data.has_key?('type') || !data.has_key?('url')
          halt 400, 'bad event'
        end

        options = {}
        begin
          options[:topic] = params['name']
          options[:type] = data.fetch('type')
          options[:url] = data.fetch('url')
          options[:data] = data.fetch('data', nil)
          options[:timestamp] = data['timestamp'] || Routemaster.now
          event = Routemaster::Models::Event.new(options)
        rescue ArgumentError => e
          _log.warn { "failed to parse event" }
          _log_exception(e)
          halt 400, 'bad event'
        rescue => e
          deliver_exception(e, custom_params: options)
          halt 500
        end

        service_options = {}
        service_options[:event] = event
        service_options[:queue] = Routemaster.batch_queue
        service_options[:topic] = topic

        Services::Ingest.new(service_options).call

        begin
          Services::KafkaPublisher.new(service_options).call
        rescue => e
          deliver_exception(e)
        end

        halt :ok
      end

      delete '/topics/:name', auth: %i[client root] do
        topic = Routemaster::Models::Topic.find(params[:name])
        halt 404 if topic.nil?
        topic.destroy
        halt 204
      end
    end
  end
end
