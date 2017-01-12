--
-- Pop items from a ZSET blow a certain score and push them into a list.
-- 
-- KEYS[1]: zset, the scheduled jobs
-- KEYS[2]: list, the queued jobs
--
-- ARGV[1]: the threshold score
-- ARGV[2]: the maximum number of items to pop
--

local items = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', ARGV[1], 'LIMIT', 0, ARGV[2])

if #items > 0 then
  redis.call('LPUSH', KEYS[2], unpack(items))
  redis.call('ZREM',  KEYS[1], unpack(items))
end

return #items
