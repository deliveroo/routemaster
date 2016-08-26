--
-- Peeks into a queue, 
-- returning the UUID and the payload of oldest message.
--
-- KEYS[1]: list of new message UUIDs
-- KEYS[2]: hash of UUIDs -> payloads
--
local uid = redis.call('LINDEX', KEYS[1], -1)
if uid == nil then
  return nil
end

local payload = redis.call('HGET', KEYS[2], uid)
return { uid, payload }
