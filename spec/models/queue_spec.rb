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

  describe '#timeout=' do
    it 'accepts integers'
    it 'rejects strings'
    it 'rejects negatives'
  end

  describe '#timeout' do
    it 'returns nil if unset'
    it 'returns an integer'
  end
end
