require 'routemaster/controllers'
require 'routemaster/models/topic'
require 'sinatra'
require 'json'

class Routemaster::Controllers::Topics < Sinatra::Base
  include Routemaster::Mixins::Log

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
    raw_data = request.body.read

    _log.info { "Received event for #{raw_data}" }

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
      event_data = JSON.parse(raw_data)
    rescue JSON::ParserError
      halt 400, 'misformated JSON'
    end

    if event_data.keys.sort != %w(type url)
      halt 400, 'bad event'
    end

    begin
      event = Routemaster::Models::Event.new(
        topic: params['name'],
        type:  event_data['type'],
        url:   event_data['url']
      )
    rescue ArgumentError
      halt 400, 'bad event'
    end

    topic.push(event)

    halt :ok
  end
end
