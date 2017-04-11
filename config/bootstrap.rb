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

require 'routemaster/mixins/log'
include Routemaster::Mixins::Log

if _log_level_invalid?
  _log.info 'Log level is wrong. "INFO" will be used instead of "' + ENV['ROUTEMASTER_LOG_LEVEL'] + '"'
end
