--		
-- Increments the attempts counter on a batch and returns all its data.
--		
-- KEYS[1]: the batch key		
--		
		
local attempts = redis.call('LINDEX', KEYS[1], 2)
if not attempts then
  return nil
else
  redis.call('LSET', KEYS[1], 2, tonumber(attempts) + 1)
  return redis.call('LRANGE', KEYS[1], 0, -1)
end

