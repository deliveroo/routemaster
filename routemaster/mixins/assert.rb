require 'routemaster/mixins'

module Routemaster::Mixins::Assert
  private

  def _assert(value, message = nil)
    return if !!value
    raise ArgumentError.new(message)
  end
end

