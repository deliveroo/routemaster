require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/services/watch'

describe Routemaster::Services::Watch do
  describe '#run' do
    context 'when no messages are queued' do
      it 'passes' do
        subject.run
      end
    end

    context 'when a message is queued' do
      context 'with an invalid message' do
        before { Routemaster.notify('foo', :bar) }

        it 'raises an exception' do
          expect { subject.run }.to raise_error
        end
      end

      shared_examples 'a service factory' do
        it 'passes' do
          expect { subject.run }.not_to raise_error
        end

        it 'calls the service' do
          expect_any_instance_of(service).to receive(:run)
          subject.run
        end
      end

      context 'with a "topic" message' do
        let(:service) { Routemaster::Services::Fanout }

        before do
          Routemaster.notify(
            'topic',
            Routemaster::Models::Topic.new(name: 'widgets', publisher: 'alice'))
        end

        it_behaves_like 'a service factory'
      end

      context 'with a "subscription" message' do
        let(:service) { Routemaster::Services::Buffer }

        before do
          Routemaster.notify(
            'subscription',
            Routemaster::Models::Subscription.new(subscriber: 'alice'))
        end

        it_behaves_like 'a service factory'
      end

      context 'with a "buffer" message' do
        let(:service) { Routemaster::Services::Deliver }

        before do
          Routemaster.notify(
            'buffer',
            Routemaster::Models::Subscription.new(subscriber: 'alice'))
        end

        it_behaves_like 'a service factory'
      end
    end
  end
end
