--
-- Push a string to a zset, iff it isn't also in a set
--
-- KEYS[1]: the zset
-- KEYS[2]: the set
--
-- ARGV[1]: the string
-- ARGV[2]: the score
--

local added = redis.call('SADD', KEYS[2], ARGV[1])

if added > 0 then
  redis.call('ZADD', KEYS[1], ARGV[2], ARGV[1])
  return 1
else
  return nil
end

