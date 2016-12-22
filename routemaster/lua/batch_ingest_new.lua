-- 
-- Create a batch with one message, and mark it as current.
--
-- KEYS[1]: set,  subscriber's current ref(s).
-- KEYS[2]: list, currently empty, the batch payload.
-- KEYS[3]: zset, the batch index
-- KEYS[4]: hash, the batch counters
-- KEYS[5]: hash, the event counters
--
-- ARGV[1]: the batch UID
-- ARGV[2]: the message data
-- ARGV[3]: the subscriber name
-- ARGV[4]: the batch creation timestamp
-- ARGV[5]: the maximum batch size
--
redis.call('RPUSH',   KEYS[2], ARGV[3], ARGV[4], 0, ARGV[2])
if tonumber(ARGV[5]) > 1 then
  -- mark the new batch as current, unless the batching limit is 1
  redis.call('SADD', KEYS[1], ARGV[1])
end  
redis.call('ZADD',    KEYS[3], ARGV[4], ARGV[1])
redis.call('HINCRBY', KEYS[4], ARGV[3], 1)
redis.call('HINCRBY', KEYS[5], ARGV[3], 1)

return true
