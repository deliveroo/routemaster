require 'routemaster/controllers'
require 'routemaster/models/topic'
require 'sinatra'
require 'json'

class Routemaster::Controllers::Topics < Sinatra::Base
  post '/topics/:name' do
    begin
      topic = Routemaster::Models::Topic.new(
        name:       params['name'], 
        publisher:  request.env['REMOTE_USER'])
    rescue Routemaster::Models::Topic::TopicClaimedError
      halt 403
      break
    end

    event_data = JSON.parse(request.body.read)
    if event_data.keys.sort != %w(type url)
      halt 400
      break
    end

    event = Routemaster::Models::Event.new(
      type: event_data['type'],
      url:  event_data['url']
    )

    topic.push(event)
    
    halt :ok
  end
end

