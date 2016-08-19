require 'rspec'

saved_environment = ENV.to_hash.freeze

RSpec.configure do |config|
  config.before(:each) { ENV.replace(saved_environment.dup) }
end
