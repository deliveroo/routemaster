--
-- Acknowledges a message
--
-- KEYS[1]: zset of pending (nacked) message UUIDs
-- KEYS[2]: hash of UUIDs -> payloads
-- ARGV[1]: message UUID
--
redis.call('ZREM', KEYS[1], ARGV[1])
redis.call('HDEL', KEYS[2], ARGV[1])
