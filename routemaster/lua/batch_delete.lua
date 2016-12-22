--
-- Delete a batch, update counters, return number of events deleted.
--
-- KEYS[1]: list, the batch payload
-- KEYS[2]: zset, the batch index
-- KEYS[3]: set,  the subscriber's current ref
-- KEYS[4]: hash, the batch counters
-- KEYS[5]: hash, the event counters
--
-- ARGV[1]: string, the batch UID
-- ARGV[2]: integer, the number of prefix elements in a batch list
-- ARGV[3]: string, the subscriber name
--
local count = redis.call('LLEN', KEYS[1])

redis.call('DEL',  KEYS[1])
redis.call('ZREM', KEYS[2], ARGV[1])
redis.call('SREM', KEYS[3], ARGV[1])

local prefix_count = tonumber(ARGV[2])
if count >= prefix_count then
  redis.call('HINCRBY', KEYS[4], ARGV[3], -1)
  redis.call('HINCRBY', KEYS[5], ARGV[3], -count+prefix_count)
  return count - prefix_count
else
  return 0
end
