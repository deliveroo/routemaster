-- 
-- Add a message to a batch, promote if full
--
-- KEYS[1]: string, subscriber's current ref. should be equal to the batch UID,
--          otherwise indicates the batch was promoted, deleted, or replaced.
-- KEYS[2]: list, the batch payload.
-- KEYS[3]: hash, the event counters
--
-- ARGV[1]: the batch UID
-- ARGV[2]: the message data
-- ARGV[3]: the subscriber name
-- ARGV[4]: the batch prefix count (number of items excluding payloads)
-- ARGV[5]: the maximum #items in a batch
--
local current_uid = redis.call('GET', KEYS[1])

-- check that this is still the current batch
if current_uid ~= ARGV[1] then
  return nil
end

redis.call('RPUSH',   KEYS[2], ARGV[2])
redis.call('HINCRBY', KEYS[3], ARGV[3], 1)

-- promote batch if full
if redis.call('LLEN', KEYS[2]) >= tonumber(ARGV[4]) + tonumber(ARGV[5]) then
  redis.call('DEL', KEYS[1])
end  

return true
