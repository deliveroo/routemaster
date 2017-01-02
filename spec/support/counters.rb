require 'routemaster/models/counters'

module SpecSupportCounter
  def get_counter(*args)
    Routemaster::Models::Counters.instance.flush.peek[args]
  end
end

RSpec.configure do |conf|
  conf.before { Routemaster::Models::Counters.instance.finalize.dump }
  conf.include SpecSupportCounter
end


