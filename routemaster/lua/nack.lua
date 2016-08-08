--
-- Negative-acknowledges a message.
--
-- KEYS[1]: list of new message UUIDs
-- KEYS[2]: zset of pending (nacked) message UUIDs
-- ARGV[1]: message UID
--
local removed = redis.call('ZREM', KEYS[2], ARGV[1])
if removed > 0 then
  redis.call('RPUSH', KEYS[1], ARGV[1])
end

