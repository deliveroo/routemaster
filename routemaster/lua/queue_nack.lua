--
-- Requeues a job
--
-- KEYS[1]: list, the worker's pending queue
-- KEYS[2]: zset, the scheduled jobs
-- KEYS[3]: set, the job index
--
-- ARGV[1]: string, the job
-- ARGV[2]: int, the deadline
--

redis.call('LREM', KEYS[1], 0, ARGV[1])
redis.call('ZADD', KEYS[2], ARGV[2], ARGV[1])
redis.call('SADD', KEYS[3], ARGV[1])

return nil
