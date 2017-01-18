require 'routemaster/models/counters'

module SpecSupportCounter
  def get_counter(name, **options)
    Routemaster::Models::Counters.instance.flush.dump[[name, options]]
  end
end

RSpec.configure do |conf|
  conf.before { Routemaster::Models::Counters.instance.reset }
  conf.include SpecSupportCounter
end


