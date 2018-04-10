require 'spec_helper'
require 'routemaster/services/codec'
require 'routemaster/models/message'
require 'routemaster/models/event'

describe Routemaster::Services::Codec do
  let(:encoded) { subject.dump(message) }
  let(:decoded) { subject.load(encoded) }

  shared_examples 'codec' do
    it 'encodes successfully' do
      expect { encoded }.not_to raise_error
    end

    it 'decodes successfully' do
      expect { decoded }.not_to raise_error
    end

    it 'is idempotent' do
      expect(decoded).to eq(message)
    end
  end

  context 'with a kill message' do
    let(:message) { Routemaster::Models::Message::Kill.new }
    include_examples 'codec'
  end

  context 'with a ping message' do
    let(:message) { Routemaster::Models::Message::Ping.new(data: 'foobar') }
    include_examples 'codec'
  end

  context 'with an event' do
    let(:message) {
      Routemaster::Models::Event.new(
        topic:      'widgets',
        type:       'create',
        url:        'https://example.com/foo/1',
        timestamp:  12345,
      )
    }
    include_examples 'codec'
  end

  context 'with garbled data' do
    let(:data) { 'hello' }

    it 'decodes to a "fake" message' do
      expect(subject.load(data)).to be_a_kind_of(Routemaster::Models::Message)
    end
  end

  context 'with an empty Hash message' do
    let(:data) do
      ['some message code', nil].to_msgpack
    end

    it 'returns garbled message' do
      expect(subject.load(data)).to be_a Routemaster::Models::Message::Garbled
    end
  end
end
