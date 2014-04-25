require 'routemaster/services/watch'
require 'routemaster/mixins/log'

include Routemaster::Mixins::Log

# The DSN can be found in Sentry by navigation to
# Account -> Projects -> [Project Name] -> [Member Name].
# Its template resembles the following:
# '{PROTOCOL}://{PUBLIC_KEY}:{SECRET_KEY}@{HOST}/{PATH}{PROJECT_ID}'

_log.info { 'creating watch' }
watch = Routemaster::Services::Watch.new

_log.info { 'trapping signals for clean exit' }
%w(INT TERM QUIT).each do |signal|
  Kernel.trap(signal) { Thread.new { watch.stop } }
end

_log.info { 'running watch' }
watch.run
_log.info { 'watch completed' }
Kernel.exit(0)
