module Routemaster
  def self.now
    (Time.now.utc.to_f * 1e3).to_i
  end

  DEFAULTS = {
    redis_pool_size: 1
  }.freeze

  def self.configure(**options)
    @_config = DEFAULTS.merge(options)
  end

  def self.config
    @_config || DEFAULTS
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
end
