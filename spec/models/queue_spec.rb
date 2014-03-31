require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/queue'

describe Routemaster::Models::Queue do
  subject { described_class.new(subscriber: 'bob') }

  describe '#initialize' do
    it 'passes' do
      expect { subject }.not_to raise_error
    end
  end

  describe '#listen_to' do
    it 'passes'

    context 'when the topic already exists' do
      it 'passes'
    end

    it 'gets listed as a subscriber'
  end
end
