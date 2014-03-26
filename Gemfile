source ENV.fetch('GEM_SOURCE', 'https://rubygems.org')


# application microframework
gem 'sinatra'

# database
gem 'hiredis'
gem 'redis', require: %w(redis redis/connection/hiredis)



group :development do 
  # SSL support for local development
  gem 'tunnels',        require: false
  # unit/functional tests
  gem 'rspec',          require: false
  # integration tests
  gem 'rack-test',      require: false
  # running tests automatically
  gem 'guard-rspec',    require: false
end
