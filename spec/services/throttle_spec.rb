require 'spec_helper'
require 'routemaster/services/throttle'
require 'routemaster/models/subscriber'
require 'routemaster/models/batch'

RSpec.describe Routemaster::Services::Throttle do
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

  subject { described_class.new(batch: batch) }

  before do
    @original_strategy = ENV['ROUTEMASTER_BACKOFF_STRATEGY']
  end

  after do
    ENV['ROUTEMASTER_BACKOFF_STRATEGY'] = @original_strategy 
    subscriber.destroy
  end


  describe '#should_deliver?' do
    def perform
      subject.should_deliver?
    end

    context 'when the backoff strategy is :batch' do
      before do
        ENV['ROUTEMASTER_BACKOFF_STRATEGY'] = 'batch'
        described_class.class_variable_set(:@@_strategy, nil)
      end

      it "returns true" do
        expect(perform).to be true
      end
    end

    context 'when the backoff strategy is :subscriber' do
      before do
        ENV['ROUTEMASTER_BACKOFF_STRATEGY'] = 'subscriber'
        described_class.class_variable_set(:@@_strategy, nil)
      end

      describe "when the subscriber is perfectly healthy" do
        let(:hp) { 100 }

        it "returns true" do
          expect(perform).to be true
        end
      end

      describe "when the subscriber is NOT healthy" do
        let(:hp) { 90 }

        describe "when the last delivery attempt to the subscriber is more recent than what the backoff would enforce" do
          let(:last_attempted_at) { Routemaster.now - 1_000 } # one second

          it "returns false" do
            expect(perform).to be false
          end
        end

        describe "when the last delivery attempt to the subscriber is older than what the backoff would enforce" do
          let(:last_attempted_at) { Routemaster.now - 180_000 } # three minutes

          it "returns true" do
            expect(perform).to be true
          end
        end
      end
    end
  end


  describe '#retry_backoff' do
    def perform
      subject.retry_backoff
    end

    context 'when the strategy is per batch backoff' do
      before do
        ENV['ROUTEMASTER_BACKOFF_STRATEGY'] = 'batch'
        described_class.class_variable_set(:@@_strategy, nil)
      end

      it "returns a backoff expressed in milliseconds" do
        expect(perform).to be_a Integer
        expect(perform).to be >= 1_000
      end

      describe "the backoffs are exponential, and depend on the failed attempts" do
        context "with one failed attempt" do
          let(:failed_attempts) { 1 }

          it "returns a number between 1 and 2 seconds" do
            expect(perform).to be_between(1_000, 2_000)
          end
        end

        context "with two failed attempts" do
          let(:failed_attempts) { 2 }

          it "returns a number between 2 and 4 seconds" do
            expect(perform).to be_between(2_000, 4_000)
          end
        end

        context "with six failed attempts" do
          let(:failed_attempts) { 6 }

          it "returns a number between 32 and 64 seconds" do
            expect(perform).to be_between(32_000, 64_000)
          end
        end
      end
    end


    context 'when the strategy is per subscriber backoff' do
      before do
        ENV['ROUTEMASTER_BACKOFF_STRATEGY'] = 'subscriber'
        described_class.class_variable_set(:@@_strategy, nil)
      end

      describe "the backoffs are exponential, and depend on the subscriber health points" do
        context "with 100 HP" do
          let(:hp) { 100 }

          it "returns zero" do
            expect(perform).to eql 0
          end
        end

        context "with 99 HP" do
          let(:hp) { 99 }

          it "returns a number between 1 and 2 seconds" do
            expect(perform).to be_between(1_000, 2_000)
          end
        end

        context "with 97 HP" do
          let(:hp) { 97 }

          it "returns a number between 2 and 4 seconds" do
            expect(perform).to be_between(2_000, 4_000)
          end
        end

        context "with 94 HP" do
          let(:hp) { 94 }

          it "returns a number between 4 and 8 seconds" do
            expect(perform).to be_between(4_000, 8_000)
          end
        end

        context "with 50 HP" do
          let(:hp) { 50 }

          it "returns a number between 32 and 64 seconds" do
            expect(perform).to be_between(32_000, 64_000)
          end
        end
      end
    end
  end
end
