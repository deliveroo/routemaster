source 'https://rubygems.org'

ruby '2.3.0'

# process runner
gem 'foreman'

# web server
gem 'unicorn'

# application microframework
gem 'sinatra'
gem 'sinatra-initializers'

# redirect to SSL, always
gem 'rack-ssl'

# database
gem 'hiredis'
gem 'redis', require: %w(redis redis/connection/hiredis)

# message management
gem 'bunny'

# talkin' sweet HTTP
gem 'faraday'
gem 'faraday_middleware'

# configuration through environement
gem 'dotenv'

# exception handling
gem 'sentry-raven', require: false
gem 'honeybadger', require: false

# monitoring
gem 'newrelic_rpm', require: false

# scheduled jobs
gem 'rufus-scheduler', require: false

# metric collection
gem 'dogapi', require: false

# Autoscaling
gem 'hirefire-resource', require: false

group :development do
  # SSL support for local development
  gem 'tunnels',        require: false
  # unit/functional tests
  gem 'rspec',          require: false
  # integration tests
  gem 'rack-test',      require: false
  # running tests automatically
  gem 'guard-rspec',    require: false
  # testing outbound HTTP
  gem 'webmock',        require: false
  # support time-dependent tests
  gem 'timecop',        require: false
  # better REPL
  gem 'pry'
  gem 'pry-nav'
  gem 'pry-remote'

  # testing against the client
  gem 'routemaster-client', git: 'https://github.com/HouseTrip/routemaster_client.git'
end
