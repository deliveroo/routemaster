require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/consumer'
require 'routemaster/models/subscription'
require 'core_ext/math'

describe Routemaster::Models::Consumer do
  let(:subscription) {
    Routemaster::Models::Subscription.new(subscriber: 'alice')
  }

  let(:options) {[ subscription ]}

  subject { described_class.new(*options) }


  describe '#initialize' do
    it 'passes with valid args' do
      expect { subject }.not_to raise_error
    end

    it 'requires subscription:' do
      options.clear
      expect { subject }.to raise_error(ArgumentError)
    end
  end


  describe '#pop' do
    it 'returns a queud message' do
      subscription.queue.publish('kill')
      message = subject.pop
      expect(message).to be_a_kind_of(Routemaster::Models::Message)
      expect(message).to be_kill
    end

    it 'delivers multiple messages' do
      10.times { subscription.queue.publish('kill') }
      10.times do
        expect(subject.pop).to be_kill
      end
    end

    it 'returns nil after the last message' do
      subscription.queue.publish('kill')
      subject.pop
      expect(subject.pop).to be_nil
    end

    it 'returns nil when there are no queued messages' do
      subject.pop
      expect(subject.pop).to be_nil
    end
  end
end
