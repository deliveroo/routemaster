require 'routemaster/models/counters'

module SpecSupportCounter
  def get_counter(name, **options)
    Routemaster::Models::Counters.instance.flush.peek[[name, options]]
  end
end

RSpec.configure do |conf|
  conf.before { Routemaster::Models::Counters.instance.finalize.dump }
  conf.include SpecSupportCounter
end


