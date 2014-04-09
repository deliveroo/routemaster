require 'routemaster/controllers'
require 'routemaster/models/topic'
require 'sinatra'

module Routemaster::Controllers
  class Subscription < Sinatra::Base
    VALID_KEYS = %w(topics callback uuid max timeout)

    post '/subscription' do
      data = JSON.parse(request.body.read)
      halt 400 if (data.keys - VALID_KEYS).any?

      topics = data['topics'].map do |name|
        Routemaster::Models::Topic.find(name)
      end
      halt 404 unless topics.all?

      halt 204
    end
  end
end
