--
-- Pops from a queue, adding to the "pending queue" in the process,
-- and returning the UUID and the payload of the message.
--
-- KEYS[1]: list of new message UUIDs
-- KEYS[2]: zset of pending (nacked) message UUIDs
-- KEYS[3]: hash of UUIDs -> payloads
-- ARGV[1]: timestamp of the event
--
local uid = redis.call('RPOP', KEYS[1])
if uid == nil then
  return nil
end

redis.call('ZADD', KEYS[2], ARGV[1], uid)

local payload = redis.call('HGET', KEYS[3], uid)
return { uid, payload }

