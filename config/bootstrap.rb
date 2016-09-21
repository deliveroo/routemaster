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
  require 'newrelic_rpm'
  GC::Profiler.enable
end
