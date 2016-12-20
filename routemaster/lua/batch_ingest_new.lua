-- 
-- Create a batch with one message.
--
-- KEYS[1]: string, subscriber's current ref. should be nil, otherwise indicates
--          a current batch was created since we checked.
-- KEYS[2]: list, currently empty, the batch payload.
-- KEYS[3]: zset, the batch index
-- KEYS[4]: hash, the batch counters
-- KEYS[5]: hash, the event counters
--
-- ARGV[1]: the batch UID
-- ARGV[2]: the message data
-- ARGV[3]: the subscriber name
-- ARGV[4]: the batch creation timestamp
--
local current_uid = redis.call('GET', KEYS[1])

if current_uid then
  return nil
end

redis.call('RPUSH',   KEYS[2], ARGV[3], ARGV[4], 0, ARGV[2])
redis.call('SET',     KEYS[1], ARGV[1])
redis.call('ZADD',    KEYS[3], ARGV[4], ARGV[1])
redis.call('HINCRBY', KEYS[4], ARGV[3], 1)
redis.call('HINCRBY', KEYS[5], ARGV[3], 1)

return true
