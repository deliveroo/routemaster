-- 
-- Removes up to N messages from a queue, forever.
-- Returns the number of messages actually removed.
--
-- KEYS[1]: list of new message UUIDs
-- KEYS[2]: hash of UUIDs -> payloads
-- ARGV[1]: number of messages to drop
--
for count = 1, ARGV[1] do
  local uid = redis.call('RPOP', KEYS[1])

  if not uid then
    return count-1
  end

  redis.call('HDEL', KEYS[2], uid)
end

return ARGV[1]
