require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'routemaster/models/job'

module Routemaster
  module Models
    # A collection of `Job`s, scheduled or queued, with deduplication and safe
    # mutation (push/pop).
    class Queue
      include Mixins::Redis
      include Mixins::Log
      include Mixins::LogException

      class Retry < StandardError
        attr_reader :delay

        DEFAULT_DELAY = 10_000 # milliseconds

        def initialize(delay = nil)
          @delay = delay ? delay : (DEFAULT_DELAY/2 + rand(DEFAULT_DELAY))
        end
      end


      def initialize(name:)
        @name = name
      end


      # Returns a list of all queued jobs.
      # Only use this for testing.
      def dump
        [].tap do |result|
          _redis.lrange(_queue_key, 0, -1).each do |raw|
            result << Job.load(raw)
          end
          _redis.zrange(_scheduled_key, 0, -1, with_scores: true).each do |raw,score|
            result << Job.load(raw, run_at: score.to_i)
          end
        end
      end

      
      # Returns the job currently being run by `worker_id`.
      def running(worker_id)
        raw = _redis.lrange(_pending_key(worker_id), 0, 0)
        return unless raw
        raw.map { |x| Job.load(x) }
      end


      # Count all jobs; or all jobs before the deadline, if specified.
      def length(deadline:nil)
        deadline ||= '+inf'
        _redis.llen(_queue_key) + _redis.zcount(_scheduled_key, '-inf', deadline)
      end


      # Adds a job to the queue.
      # If an identical job is already queued, do nothing.
      # Returns truthy iff a job was actually added.
      def push(job)
        if job.run_at
          _redis_lua_run(
            'queue_push_scheduled',
            keys: [_scheduled_key, _index_key],
            argv: [job.dump, job.run_at])
        else
          _redis_lua_run(
            'queue_push_instant',
            keys: [_queue_key, _index_key],
            argv: [job.dump])
        end
      end


      # Block and pop a job from the queue, marking it as acquired by the
      # worker, and yield it.
      # If the block raises Retry, the job will be requeued.
      # On any other exception, or in successful execution the job will be
      # discarded.
      def pop(worker_id)
        pending_key = _pending_key(worker_id)

        if _redis.llen(pending_key) > 0
          raise "Worker '#{worker_id}' already has a batch acquired"
        end

        job_data = _redis.brpoplpush(_queue_key, pending_key, timeout: _acquire_timeout)
        return if job_data.nil?

        job = Job.load(job_data)
        yield job

        _redis_lua_run(
          'queue_ack',
          keys: [pending_key, _index_key],
          argv: [job_data])

        true
      rescue Retry => e
        run_at = Routemaster.now + e.delay

        _redis_lua_run(
          'queue_nack',
          keys: [pending_key, _scheduled_key, _index_key],
          argv: [job_data, run_at])
      rescue StandardError => e
        _log.warn("failed to process #{job.inspect}")
        raise
      end


      # Promote a specific scheduled job to the main queue.
      # Returns truthy iff there was a job to promote.
      def promote(job)
        _redis_lua_run(
          'queue_promote',
          keys: [_scheduled_key, _queue_key, _index_key],
          argv: [job.dump])
      end


      # Move scheduled jobs to the main queue when we're past their `run_at`
      # target.
      # Does not enqueue duplicate jobs.
      # Return the number of jobs promoted.
      def schedule(deadline: Routemaster.now, batch_size: 100)
        _redis_lua_run(
          'queue_schedule',
          keys: [_scheduled_key, _queue_key],
          argv: [deadline, batch_size])
      end
      

      # Re-queue all jobs marked as aquired, if the block returns true for a
      # worker ID.
      def scrub
        _redis.scan_each(match: _pending_key('*'), count: 10) do |key|
          worker_id = key.split(':').last
          next unless yield worker_id

          _redis_lua_run(
            'queue_scrub',
            keys: [key, _queue_key, _index_key])
          _log.warn { "scrubbed worker.#{worker_id}" }
        end
      end


      private

      def _acquire_timeout
        @_acquire_timeout ||= Integer(ENV.fetch('ROUTEMASTER_ACQUIRE_TIMEOUT'))
      end

      def _pending_key(worker_id)
        "jobs:pending:#{@name}:#{worker_id}"
      end

      def _queue_key
        "jobs:queue:#{@name}"
      end

      def _index_key
        "jobs:index:#{@name}"
      end

      def _scheduled_key
        "jobs:scheduled:#{@name}"
      end
    end
  end
end

