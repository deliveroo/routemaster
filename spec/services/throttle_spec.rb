require 'spec_helper'
require 'routemaster/services/throttle'
require 'routemaster/models/subscriber'

RSpec.describe Routemaster::Services::Throttle do
  let(:last_attempted_at) { Routemaster.now - 10_000 }
  let(:hp) { 50 }
  let(:decrement) { -2 }
  let(:increment) { 1 }

  let(:subscriber) do
    Routemaster::Models::Subscriber.new(
      name: 'hedgehog',
      attributes: {
        'last_attempted_at' => last_attempted_at,
        'health_points' => hp.to_s
      }
    ).save
  end

  def reloaded_subscriber
    Routemaster::Models::Subscriber.new(name: subscriber.name)
  end

  subject { described_class.new(subscriber) }


  describe '#check!' do
    let(:time) { Routemaster.now }

    def perform
      subject.check!(time)
    end

    shared_examples 'it updates the last_attempted_at timestamp' do
      it 'updates the last_attempted_at timestamp on the Subscriber object' do
        old_value = subscriber.last_attempted_at
        new_value = nil

        expect { perform rescue nil }.to change {
          new_value = reloaded_subscriber.last_attempted_at
        }

        expect(new_value).to be > old_value.to_i # to_i in case it's nil
      end
    end


    describe "when the subscriber is perfectly healthy" do
      let(:hp) { 100 }

      it "returns true" do
        expect(perform).to be true
      end

      it_behaves_like 'it updates the last_attempted_at timestamp'
    end


    describe "when the subscriber is NOT healthy" do
      let(:hp) { 90 }

      describe "when the subscriber has never received an event before (its last_attempted_at timestamp is nil)" do
        let(:last_attempted_at) { nil }

        it "returns true" do
          expect(perform).to be true
        end

        it_behaves_like 'it updates the last_attempted_at timestamp'
      end


      describe "when the subscriber has received events before (its last_attempted_at timestamp contains a value)" do
        let(:last_attempted_at) { 1 }

        describe "when the last delivery attempt to the subscriber is more recent than what the backoff would enforce" do
          let(:last_attempted_at) { Routemaster.now - 800 } # one second

          it 'raises an EarlyThrottle exception' do
            expect {
              perform
            }.to raise_error(Routemaster::Exceptions::EarlyThrottle)
          end

          specify 'the exception carries tha name of the subscriber' do
            error = nil
            begin
              perform
            rescue => e
              error = e
            end

            expect(error.message).to match /#{subscriber.name}/
          end

          it 'does NOT update the last_attempted_at timestamp on the Subscriber object' do
            expect { perform rescue nil }.to_not change {
              reloaded_subscriber.last_attempted_at
            }
          end
        end

        describe "when the last delivery attempt to the subscriber is older than what the backoff would enforce" do
          let(:last_attempted_at) { Routemaster.now - 180_000 } # three minutes

          it "returns true" do
            expect(perform).to be true
          end

          it_behaves_like 'it updates the last_attempted_at timestamp'
        end
      end
    end
  end


  describe '#retry_backoff' do
    def perform
      subject.retry_backoff
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

        it "returns the right value" do
          expect(perform).to be_between(524, 1050)
        end
      end

      context "with 97 HP" do
        let(:hp) { 97 }

        it "returns the right value" do
          expect(perform).to be_between(578, 1157)
        end
      end

      context "with 78 HP" do
        let(:hp) { 78 }

        it "returns the right value" do
          expect(perform).to be_between(1453, 2908)
        end
      end

      context "with 50 HP" do
        let(:hp) { 50 }

        it "returns the right value" do
          expect(perform).to be_between(5656, 11314)
        end
      end

      context "with 15 HP" do
        let(:hp) { 15 }

        it "returns the right value" do
          expect(perform).to be_between(30909, 61820)
        end
      end
    end
  end


  describe '#notice_failure' do
    it 'lowers the health points of the subscriber' do
      expect {
        subject.notice_failure
      }.to change {
        reloaded_subscriber.health_points
      }.from(hp).to(hp + decrement)
    end
  end

  describe '#notice_success' do
    it 'raises the health points of the subscriber' do
      expect {
        subject.notice_success
      }.to change {
        reloaded_subscriber.health_points
      }.from(hp).to(hp + increment)
    end
  end
end
