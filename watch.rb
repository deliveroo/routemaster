require 'routemaster/services/watch'
require 'routemaster/mixins/log'

include Routemaster::Mixins::Log

_log.info { 'creating watch' }
watch = Routemaster::Services::Watch.new

_log.info { 'trapping signals for clean exit' }
%w(INT TERM QUIT).each do |signal|
  Kernel.trap(signal) { Thread.new { watch.cancel } }
end

_log.info { 'running watch' }
watch.run
_log.info { 'watch completed' }
Kernel.exit(0)
