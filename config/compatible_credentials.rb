# Import credentials from ROUTEMASTER_CLIENTS.
#
# This must be run after boostrapping, and after Redis has been configured.
#
if ENV['ROUTEMASTER_CLIENTS']
  require 'routemaster/mixins/redis'
  require 'routemaster/mixins/log'
  require 'routemaster/models/client_token'
  $stderr.puts 'Warning: Migrating $ROUTEMASTER_CLIENTS to redis storage. Support adding clients via environment variable is deprecated. See README.'

  ENV.fetch('ROUTEMASTER_CLIENTS', '').split(',').each do |token|
    name = token.sub(/--.*/, '')
    Routemaster::Models::ClientToken.create!(name: name, token: token)
  end
end

