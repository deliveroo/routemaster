require 'spec_helper'
require 'routemaster/application'
require 'spec/support/rack_test'

describe Routemaster::Application do
  let(:app) { described_class }

  describe 'unknown endpoint' do
    it 'responds with an error, no content' do
      ENV['ROUTEMASTER_CLIENTS'] = 'demo'
      authorize 'demo', 'x'
      post '/whatever'
      expect(last_response).to be_not_found
      expect(last_response.body).to be_empty
    end
  end
end
