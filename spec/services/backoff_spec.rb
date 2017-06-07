require 'spec_helper'
require 'routemaster/services/backoff'
require 'routemaster/models/subscriber'
require 'routemaster/models/batch'

RSpec.describe Routemaster::Services::Backoff do
  let(:last_attempted_at) { Routemaster.now - 10_000 }
  let(:hp) { 50 }

  let(:subscriber) do
    Routemaster::Models::Subscriber.new(
      name: 'hedgehog',
      attributes: {
        'last_attempted_at' => last_attempted_at,
        'health_points' => hp.to_s
      }
    ).save
  end

  let(:failed_attempts) { 1 }
  let(:batch) do
    instance_double(Routemaster::Models::Batch, subscriber: subscriber, fail: failed_attempts)
  end

  subject { described_class.new(batch) }

  after do
    subscriber.destroy
  end


  describe '#calculate' do
    before { @original = ENV['ROUTEMASTER_BACKOFF_STRATEGY'] }
    after  { ENV['ROUTEMASTER_BACKOFF_STRATEGY'] = @original }

    def perform
      subject.calculate
    end

    context 'when the strategy is per batch backoff' do
      before do
        ENV['ROUTEMASTER_BACKOFF_STRATEGY'] = 'batch'
        described_class.class_variable_set(:@@_strategy, nil)
      end

      it "returns a backoff expressed in milliseconds" do
        expect(perform).to be_a Integer
        expect(perform).to be >= 1000
      end

      describe "the backoffs are exponential, and depend on the failed attempts" do
        context "with one failed attempt" do
          let(:failed_attempts) { 1 }

          it "returns a number between 1 and 2 seconds" do
            expect(perform).to be_between(1000, 2000)
          end
        end

        context "with two failed attempts" do
          let(:failed_attempts) { 2 }

          it "returns a number between 2 and 4 seconds" do
            expect(perform).to be_between(2000, 4000)
          end
        end

        context "with six failed attempts" do
          let(:failed_attempts) { 6 }

          it "returns a number between 32 and 64 seconds" do
            expect(perform).to be_between(32000, 64000)
          end
        end
      end
    end


    context 'when the strategy is per subscriber backoff' do
      before do
        ENV['ROUTEMASTER_BACKOFF_STRATEGY'] = 'subscriber'
        described_class.class_variable_set(:@@_strategy, nil)
      end

      it "returns a backoff expressed in milliseconds" do
        expect(perform).to be_a Integer
        expect(perform).to be >= 1000
      end
    end
  end
end
