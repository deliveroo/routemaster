--
-- Delete a batch.
--
-- KEYS[1]: list, the batch payload
-- KEYS[2]: zset, the batch index
-- KEYS[3]: string, the subscriber's current ref
--
-- ARGV[1]: string, the batch UID
--
redis.call('DEL',  KEYS[1])
redis.call('ZREM', KEYS[2], ARGV[1])

if ARGV[1] == redis.call('GET', KEYS[3]) then
  redis.call('DEL', KEYS[3])
end
return nil
