-- 
-- Add a message to a batch
--
-- KEYS[1]: string, subscriber's current ref. should be equal to the batch UID,
--          otherwise indicates the batch was promoted, deleted, or replaced.
-- KEYS[2]: list, the batch payload.
-- KEYS[3]: hash, the event counters
--
-- ARGV[1]: the batch UID
-- ARGV[2]: the message data
-- ARGV[3]: the subscriber name
--
local current_uid = redis.call('GET', KEYS[1])

if current_uid ~= ARGV[1] then
  return nil
end

redis.call('RPUSH',   KEYS[2], ARGV[2])
redis.call('HINCRBY', KEYS[3], ARGV[3], 1)

return true
