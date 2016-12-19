--
-- Delete a batch.
--
-- KEYS[1]: list, the batch payload
-- KEYS[2]: zset, the batch index
--
-- ARGV[1]: string, the batch UID
--
redis.call('DEL',  KEYS[1])
redis.call('ZREM', KEYS[2], ARGV[1])
return nil
