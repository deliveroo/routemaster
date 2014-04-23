require 'routemaster/models/event'

module MakeEvent
  def make_event
    @event_counter ||= 0
    @event_counter += 1
    Routemaster::Models::Event.new(
      topic: 'widgets',
      type:  'noop',
      url:   "https://example.com/widgets/#{@event_counter}")
  end
end

RSpec.configure do |conf|
  conf.include MakeEvent
end

