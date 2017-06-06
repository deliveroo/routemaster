--
-- Atomically changes the health points of a subscriber and
-- verifies these constraints:
--    max: 100
--    min: 0
--    
--
-- KEYS[1]: hash, a subscriber key
--
-- ARGV[1]: a signed integer, to be applied as an offset
--

local offset = tonumber(ARGV[1])

-- Set the default value, if null
redis.call('HSETNX', KEYS[1], 'health_points', 100)

-- Increment the value and return the new current value, as an integer
local new_value = tonumber(redis.call('HINCRBY', KEYS[1], 'health_points', offset))

-- Check the boundaries of the range
if new_value > 100 then
  redis.call('HSET', KEYS[1], 'health_points', 100)
  return 100
elseif new_value < 0 then
  redis.call('HSET', KEYS[1], 'health_points', 0)
  return 0
else
  return new_value
end

