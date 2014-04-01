module Routemaster
  def self.now
    (Time.now.utc.to_f * 1e3).to_i
  end
end
