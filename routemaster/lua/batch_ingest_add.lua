-- 
-- Add a message to a batch, promote if full
--
-- KEYS[1]: set, subscriber's current ref.
--          should contain the batch UID,
--          otherwise indicates the batch was promoted, or deleted.
-- KEYS[2]: list, the batch payload.
-- KEYS[3]: hash, the event counters
--
-- ARGV[1]: the batch UID
-- ARGV[2]: the message data
-- ARGV[3]: the subscriber name
-- ARGV[4]: the batch prefix count (number of items excluding payloads)
-- ARGV[5]: the maximum #items in a batch
--

-- FIXME
-- merge the 2 cases into an add/create Lua script
-- pass it both the expected and a potential new batch UID
-- return the effective UID

-- check that this is still a current batch
if redis.call('SISMEMBER', KEYS[1], ARGV[1]) < 1 then
  return nil
end

redis.call('RPUSH',   KEYS[2], ARGV[2])
redis.call('HINCRBY', KEYS[3], ARGV[3], 1)

-- promote batch if full
if redis.call('LLEN', KEYS[2]) >= tonumber(ARGV[4]) + tonumber(ARGV[5]) then
  redis.call('SREM', KEYS[1], ARGV[1])
end  

return true
