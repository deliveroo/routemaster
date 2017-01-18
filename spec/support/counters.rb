require 'routemaster/models/counters'

module SpecSupportCounter
  def get_counter(*args)
    Routemaster::Models::Counters.instance.flush.dump[args]
  end
end

RSpec.configure do |conf|
  conf.before { Routemaster::Models::Counters.instance.reset }
  conf.include SpecSupportCounter
end


