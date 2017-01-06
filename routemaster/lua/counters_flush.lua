--
-- Bulk increment counters, handling overflow.
--
-- KEYS[1]:    hash, the counters
--
-- ARGV[2k-1]: counter key
-- ARGV[2k]:   increment value
--

for k = 1, #ARGV/2 do
  local field = ARGV[2*k-1]
  local incr  = ARGV[2*k]

  local result = redis.pcall('HINCRBY', KEYS[1], field, incr)
  if type(result) == 'table' and result.err then
    redis.call('HSET', KEYS[1], field, incr)
  end
end
