--
-- Increments and returns the attempts counter on a batch.
--
-- KEYS[1]: the batch key
--

local attempts = redis.call('LINDEX', KEYS[1], 2)
if attempts == nil then return end

attempts = tonumber(attempts) + 1
redis.call('LSET', KEYS[1], 2, attempts)

return attempts
