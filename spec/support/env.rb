require 'rspec'

saved_environment = ENV.to_hash.freeze

RSpec.configure do |config|
  config.after(:each) { ENV.replace(saved_environment.dup) }
end
