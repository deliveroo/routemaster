require 'routemaster/models/messages'

module TestNotifications
  def last_notification
    Routemaster::Models::Messages.instance.peek
  end

  def notifications
    Routemaster::Models::Messages.instance
  end
end

RSpec.configure do |conf|
  conf.include TestNotifications
end
