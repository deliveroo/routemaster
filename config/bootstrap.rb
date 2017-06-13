# Set up a minimal environment:
# - rubygems and bundler
# - valid ENV based on the libc environment and Dotenv files
# - suitable load path
# - New Relic

require 'rubygems'
require 'bundler/setup'
require 'dotenv'

dir = File.expand_path('../..', __FILE__)
$:.unshift(dir) unless $:.include?(dir)

Dotenv.load!('.env')
Dotenv.overload('.env.local') if ENV['RACK_ENV'] == 'development'

if ENV['NEW_RELIC_LICENSE_KEY']
  require 'redis'
  require 'newrelic_rpm'
  GC::Profiler.enable

  require 'routemaster/models/job'
  Routemaster::Models::Job.class_eval do
    include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

    alias_method :perform_without_transaction_rename, :perform
    def perform
      NewRelic::Agent.set_transaction_name("#{self.class.name}/#{@name}")
      perform_without_transaction_rename
    end

    add_transaction_tracer :perform, :category => :task
  end
end

if ENV['ROUTEMASTER_CLIENTS']
  require 'routemaster/mixins/redis'
  require 'routemaster/mixins/log'
  $stderr.puts "Warning: Migrating $ROUTEMASTER_CLIENTS to redis storage. Support adding clients via environment variable is deprecated. See README"
  ENV.fetch('ROUTEMASTER_CLIENTS', '').split(',').each do |old_id|
    service_name, uuid = old_id.split "--"
    Object.new.extend(Routemaster::Mixins::Redis)._redis.hset("api_keys", uuid, service_name)
  end
end
