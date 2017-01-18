source 'https://rubygems.org'

ruby '2.3.3'

# process runner
gem 'foreman'

# web server
gem 'puma'

# application microframework
gem 'sinatra'

# redirect to SSL, always
gem 'rack-ssl'

# database
gem 'redis'
gem 'redis-namespace'
gem 'connection_pool'

# fast, redis-compatible serialisation
gem 'msgpack'

# talkin' sweet HTTP
gem 'faraday'
gem 'faraday_middleware'
gem 'typhoeus'
gem 'oj'

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

# Debugging in staging/production
gem 'pry', require: false

group :development do
  # SSL support for local development
  gem 'tunnels',        require: false
  # unit/functional tests
  gem 'rspec',          require: false
  gem 'rspec-its',      require: false
  # integration tests
  gem 'rack-test',      require: false
  # running tests automatically
  gem 'guard-rspec',    require: false
  # testing outbound HTTP
  gem 'webmock',        require: false
  # better REPL
  gem 'pry-byebug'
  gem 'pry-remote'

  # testing against the client
  gem 'routemaster-client', git: 'https://github.com/deliveroo/routemaster-client.git', ref: '0521e2f'
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
end
