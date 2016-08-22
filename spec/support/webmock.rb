require 'rspec'
require 'webmock/rspec'

RSpec.configure do |config|
  config.before(:each) { WebMock.enable! }
  config.after(:suite) { WebMock.disable! }
end

