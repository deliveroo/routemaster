--
-- Return all data for the named subscribers.
--
-- KEYS[1]: set,  the subscriber index
-- KEYS[2]: hash, a subscriber key
-- KEYS[3]: ...
--
-- ARGV[1]: name of the 1st subscriber
-- ARGV[2]: ...
--
-- Result: array of name, metadata pairs
--

local index_key = KEYS[1]
local result = {}

for k, name in ipairs(ARGV) do
  if redis.call('SISMEMBER', index_key, name) > 0 then
    local data = redis.call('HGETALL', KEYS[k+1])
    table.insert(result, { name, data })
  end
end

return result
