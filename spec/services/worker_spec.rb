require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'spec/support/dummy'
require 'spec/support/env'
require 'routemaster/services/worker'
require 'routemaster/services/codec'
require 'routemaster/services/deliver'

module Routemaster
  describe Services::Worker do
    subject { described_class.new(queue: queue) }

    let(:queue) { double 'queue' }
    let(:job) { double 'job' }

    before do
      allow(queue).to receive(:pop)
    end

    describe '#call' do
      let(:perform) { subject.call }

      it 'pops jobs from the queue' do
        expect(queue).to receive(:pop).with(subject.id)
        perform
      end

      it 'performs jobs' do
        allow(queue).to receive(:pop).and_yield(job)
      end
    end

    describe '#last_at' do
      let(:result) { subject.last_at }

      it { expect(result).to be_nil }

      context 'once the worker has run' do
        before { subject.call }

        it { expect(result).to be_between(Routemaster.now - 1000, Routemaster.now) }
      end
    end

    describe '#cleanup' do
      before { subject.call }

      it 'removes last_at' do
        expect { subject.cleanup }.to change { subject.last_at }.to(nil)
      end
    end

    describe '.each' do
      let(:result) { [].tap { |r| described_class.each { |x| r << x } } }
      it 'yields workers' do
        subject.call
        expect(result).to eq([subject])
      end
    end
  end
end
