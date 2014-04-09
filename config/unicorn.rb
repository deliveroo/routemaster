# Unicorn configuration

# listen on both a Unix domain socket and a TCP port,
# we use a shorter backlog for quicker failover when busy
# listen "/tmp/.sock", :backlog => 64
# listen 8080, :tcp_nopush => true
listen Integer(ENV.fetch('PORT',8080)), tcp_nopush: false, tcp_nodelay: true

# nuke workers after x seconds instead of 60 seconds (the default)
timeout Integer(ENV.fetch('ROUTEMASTER_WEB_TIMEOUT', 5))

# Use at least one worker per core if you're on a dedicated server,
# more will usually help for _short_ waits on databases/caches.
worker_processes Integer(ENV.fetch('ROUTEMASTER_WEB_WORKERS',10))

# combine Ruby 2.0.0dev or REE with "preload_app true" for memory savings
# http://rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
preload_app true



before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  # Throttle the master from forking too quickly by sleeping.  Due
  # to the implementation of standard Unix signal handlers, this
  # helps (but does not completely) prevent identical, repeated signals
  # from being lost when the receiving process is busy.
  if ENV.fetch('RACK_ENV', 'development') =~ /production|staging/
    sleep 250e-3
  end
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end
end
