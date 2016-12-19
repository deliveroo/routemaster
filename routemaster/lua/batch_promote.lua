--
-- Promote a batch from current to pending, ie. remove it as a reference
-- to its subscriber's "current" pointer.
--
-- KEYS[1]: string, the current ref for this subscriber
--
-- ARGV[1]: string, the batch UID
--

local current_uid = redis.call('GET', KEYS[1])

if current_uid == ARGV[1] then
  redis.call('DEL', KEYS[1])
end
