require 'wisper'

module Routemaster
  def self.now
    (Time.now.utc.to_f * 1e3).to_i
  end

  def self.configure(**options)
    @_config = options

    require 'routemaster/services/update_counters'
    Routemaster::Services::UpdateCounters.instance.setup

    counters.incr('process', type: config[:process_type], status: 'start')
    self
  end

  def self.teardown
    counters.incr('process', type: config[:process_type], status: 'stop').finalize
  end

  def self.config
    {
      redis_pool_size: 1
    }.merge(@_config || {})
  end

  def self.batch_queue
    @_batch_queue ||= begin
      require 'routemaster/models/queue'
      Models::Queue.new(name: 'main')
    end
  end

  def self.aux_queue
    @_aux_queue ||= begin
      require 'routemaster/models/queue'
      Models::Queue.new(name: 'aux')
    end
  end

  def self.counters
    @_counters ||= begin
      require 'routemaster/models/counters'
      Models::Counters.instance
    end
  end
end
