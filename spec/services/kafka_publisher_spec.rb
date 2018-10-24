require 'spec_helper'
require 'routemaster/services/kafka_publisher'
require 'routemaster/models/topic'
require 'spec/support/events'

describe Routemaster::Services::KafkaPublisher do
  describe '#call' do
    let(:options) {{
      topic: Routemaster::Models::Topic.find_or_create!(name: 'some_topic', publisher: 'some-publisher--uid123'),
      event: make_event,
    }}
    let(:instance) { described_class.new(options) }
    subject(:call) { instance.call }

    it 'succeeds without errors' do
      expect { call }.to_not raise_error
    end
  end
end
