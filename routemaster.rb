module Routemaster
  def self.now
    (Time.now.utc.to_f * 1e3).to_i
  end

  DEFAULTS = {
    redis_pool_size: 1,
    process_type:    'unknown',
  }.freeze

  def self.configure(**options)
    @_config = DEFAULTS.merge(options)
    counters.incr('process', type: config[:process_type], status: 'start')
    self
  end

  def self.teardown
    counters.incr('process', type: config[:process_type], status: 'stop').finalize
    self
  end

  def self.config
    @_config || DEFAULTS
  end

  def self.batch_queue
    @_batch_queue ||= begin
      require 'routemaster/models/queue'
      Models::Queue::MAIN
    end
  end

  def self.aux_queue
    @_aux_queue ||= begin
      require 'routemaster/models/queue'
      Models::Queue::AUX
    end
  end

  def self.counters
    @_counters ||= begin
      require 'routemaster/models/counters'
      Models::Counters.instance
    end
  end
end
