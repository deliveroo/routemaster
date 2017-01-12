--
-- Move one string from a ZSET to a list, if it exists.
-- 
-- KEYS[1]: zset, the scheduled jobs
-- KEYS[2]: list, the queued jobs
--
-- ARGV[1]: the string to move
--

local score = redis.call('ZSCORE', KEYS[1], ARGV[1])

if score then
  redis.call('LPUSH', KEYS[2], ARGV[1])
  redis.call('ZREM',  KEYS[1], ARGV[1])
end
return score

