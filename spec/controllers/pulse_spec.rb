require 'spec_helper'
require 'routemaster/controllers/pulse'
require 'spec/support/rack_test'
require 'spec/support/persistence'
require 'spec/support/env'

describe Routemaster::Controllers::Pulse, type: :controller do
  let(:app) { described_class }

  describe 'GET /pulse' do
    let(:perform) { get '/pulse' }

    context 'when all is fine' do
      it 'succeeds' do
        perform
        expect(last_response.status).to eq(204)
      end

      it 'does not return anything' do
        perform
        expect(last_response.body).to be_empty
      end
    end

    context 'when the pulse service fails' do
      before { allow_any_instance_of(Routemaster::Services::Pulse).to receive(:run).and_return(false) }

      it 'returns 500' do
        perform
        expect(last_response).to be_server_error
      end
    end
  end


  describe 'GET /pulse/scaling' do
    let(:perform) { get '/pulse/scaling' }
    let(:duration) {
      start_at = Routemaster.now
      perform
      Routemaster.now - start_at
    }
    let(:job_count) { 0 }
    let(:job_deadline) { Routemaster.now }

    before do
      ENV['ROUTEMASTER_SCALING_THRESHOLD'] = '10'
      ENV['ROUTEMASTER_SCALING_THRESHOLD'] = '10'

      Routemaster::Models::Queue::MAIN.tap do |q|
        job_count.times do |idx|
          q.push Routemaster::Models::Job.new(name: 'null', args: idx, run_at: job_deadline)
        end
      end
    end

    shared_examples 'scale-down advisory' do
      it { expect(perform).to be_successful }
      it { expect(duration).to be < 1000 }
    end

    shared_examples 'scale-up advisory' do
      it { expect(perform).to be_successful }
      it { expect(duration).to be >= 1000 }
    end

    context 'when there are no queued jobs' do
      it_behaves_like 'scale-down advisory'
    end

    context 'when there are scheduled jobs' do
      let(:job_count) { 10 }
      let(:job_deadline) { Routemaster.now + 10_000 }
      it_behaves_like 'scale-down advisory'
    end

    context 'when there are few almost-due jobs' do
      let(:job_count) { 9 }
      let(:job_deadline) { Routemaster.now + 100 }
      it_behaves_like 'scale-down advisory'
    end

    context 'when there are many almost-due jobs', slow: true do
      let(:job_count) { 10 }
      let(:job_deadline) { Routemaster.now + 100 }
      it_behaves_like 'scale-up advisory'
    end
  end
end
