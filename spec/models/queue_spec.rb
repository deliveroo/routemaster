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
    it 'accepts integers' do
      expect { subject.timeout = 123 }.not_to raise_error
    end

    it 'rejects strings' do
      expect { subject.timeout = '123' }.to raise_error
    end

    it 'rejects negatives' do
      expect { subject.timeout = -123 }.to raise_error
    end

  end

  describe '#timeout' do
    it 'returns nil if unset' do
      expect(subject.timeout).to be_nil
    end

    it 'returns an integer' do
      subject.timeout = 123
      expect(subject.timeout).to eq(123)
    end
  end
end
