source 'https://rubygems.org'

ruby '2.3.1'

# process runner
gem 'foreman'

# web server
gem 'puma'

# application microframework
gem 'sinatra'
gem 'sinatra-initializers'

# redirect to SSL, always
gem 'rack-ssl'

# database
gem 'hiredis'
gem 'redis', require: %w(redis redis/connection/hiredis)
gem 'redis-namespace'

# fast, redis-compatible serialisation
gem 'msgpack'

# talkin' sweet HTTP
gem 'faraday'
gem 'faraday_middleware'
gem 'typhoeus'

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
  gem 'routemaster-client', git: 'https://github.com/deliveroo/routemaster-client.git', ref: '6f7af94'
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
end
