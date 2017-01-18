require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/counters'
require 'routemaster/models/queue'
require 'routemaster/models/job'

describe Routemaster::Models::Queue do
  subject { described_class.new(name: 'main') }

  def make_job(x:0, at:nil)
    Routemaster::Models::Job.new(name: 'null', args:x, run_at:at)
  end

  describe '#push' do
    shared_examples 'pusher' do
      let(:perform) { subject.push(job) }

      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'returns true' do
        expect(perform).to be_truthy
      end

      it 'persists the job' do
        perform
        expect(subject.jobs).to eq([job])
      end

      shared_examples 'deduplicates' do
        it 'does not queue an identical job' do
          subject.push(job)
          expect(subject.jobs.length).to eq(1)
        end

        it 'returns false' do
          subject.push(job)
          expect(subject.push(job)).to be_falsy
        end
      end

      context 'when an instant job is present' do
        before { subject.push make_job }
        it_behaves_like 'deduplicates'
      end

      context 'when an scheduled job is present' do
        before { subject.push make_job(at: 1234) }
        it_behaves_like 'deduplicates'
      end
    end

    context 'instant job' do
      let(:job) { make_job }
      it_behaves_like 'pusher'
    end

    context 'scheduled job' do
      let(:job) { make_job(at: 4567) }
      it_behaves_like 'pusher'
    end
  end

  describe '#length' do
    before do
      subject.push make_job(x:1)
      subject.push make_job(x:2)
      subject.push make_job(x:3, at: 100)
      subject.push make_job(x:4, at: 200)
    end

    it 'counts all jobs without args' do
      expect(subject.length).to eq(4)
    end

    it 'counts jobs before the specified deadline' do
      expect(subject.length(deadline: 100)).to eq(3)
    end
  end

  describe '#pop' do
    let(:callback) { ->(job) { @job = job} }
    let(:perform) { subject.pop('foo', &callback) }

    context 'when there is no job', slow: true do
      it 'is falsy' do
        expect(perform).to be_falsy
      end
    end

    context 'with a pending job' do
      before { subject.push(make_job) }

      it 'yields the job' do
        perform
        expect(@job).not_to be_nil
      end

      it 'removes the job' do
        perform
        expect(subject.jobs).to eq([])
      end

      context 'when Retry is raised' do
        let(:callback) { ->(job) { raise described_class::Retry,1 } }
        
        it 'reschedules the job' do
          perform
          expect(subject.jobs).to eq([make_job])
          expect(subject.jobs.first.run_at).not_to be_nil
        end
      end

      context 'on errors' do
        let(:callback) { ->(job) { raise 'oh noes' } }

        it 'removes the job' do
          perform rescue nil
          expect(subject.jobs).to be_empty
        end

        it 'raises the error' do
          expect { perform }.to raise_error(RuntimeError)
        end
      end
    end
  end


  describe '#promote' do
    let(:perform) { subject.promote(job) }

    context 'when the job does not exist' do
      let(:job) { make_job(at: 1234) }

      it 'is falsy' do
        expect(perform).to be_falsy
      end

      it 'does not add the job' do
        expect { perform }.not_to change { subject.jobs }
      end
    end

    context 'when the job exists and is scheduled' do
      let(:job) { make_job(at: 1234) }
      before { subject.push(job) } 

      it 'is truthy' do
        expect(perform).to be_truthy
      end

      it 'removes the deadline' do
        expect { perform }.to change { subject.jobs.first.run_at }.to(nil)
      end
    end

    context 'when the job exists and is instant' do
      let(:job) { make_job(at: nil) }
      before { subject.push(job) } 

      it 'is truthy' do
        expect(perform).to be_falsy
      end

      it 'removes the deadline' do
        expect { perform }.not_to change { subject.jobs.first.run_at }
      end
    end
  end


  describe '#schedule' do
    let(:job_count) { 10 }
    let(:deadline) { 5 }
    let(:perform) { subject.schedule(deadline: deadline) }

    before do
      1.upto(job_count) do |idx|
        subject.push make_job(x: idx, at: idx)
      end
    end

    context 'when there are no jobs' do
      let(:job_count) { 0 }

      it { expect { perform }.not_to raise_error } 
    end

    context 'with 10 jobs' do
      it 'does not add or remove jobs' do
        expect { perform }.not_to change { subject.jobs.length }
      end

      it 'schedules the jobs below the deadline' do
        perform
        subject.jobs.each do |job|
          if job.args.first <= 5
            expect(job.run_at).to be_nil
          else
            expect(job.run_at).to eq(job.args.first)
          end
        end
      end
    end
  end


  describe '#scrub' do
    include Routemaster::Mixins::Redis

    let(:job1) { make_job x: 1 }
    let(:job2) { make_job x: 2 }
    let(:perform) { subject.scrub(&callback) }
    let(:callback) { ->(id) { id == 'foo' } }

    before do
      subject.push(job1)
      subject.push(job2)

      subject.pop('foo') { raise 'abort' } rescue nil
      subject.pop('qux') { raise 'abort' } rescue nil
    end

    it 're-adds the job' do
      expect { perform }.to change { subject.jobs }.to([job1])
    end

    it 'unmarks the job as pending' do
      expect { perform }.to change { 
        subject.running_jobs('foo')
      }.from([job1]).to([])
    end

    it 'does not affect still-running workers' do
      expect { perform }.not_to change {
        subject.running_jobs('qux')
      }
    end

    it 'increments jobs.scrubbed' do
      expect { perform }.to change {
        get_counter('jobs.scrubbed', queue: 'main')
      }.by(1)
    end
  end
end
