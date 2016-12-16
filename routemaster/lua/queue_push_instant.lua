--
-- Push a string to a list, iff it isn't also in a set
--
-- KEYS[1]: the list
-- KEYS[2]: the set
--
-- ARGV[1]: the string
--

local added = redis.call('sadd', KEYS[2], ARGV[1])

if added > 0 then
  redis.call('LPUSH', KEYS[1], ARGV[1])
  return 1
else
  return nil
end

