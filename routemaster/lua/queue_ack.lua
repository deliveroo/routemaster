--
-- Acknowledges a job, deleting from the set of known jobs
-- and from the pending list.
--
-- KEYS[1]: list, the worker's pending queue
-- KEYS[2]: set, the job index
--
-- ARGV[1]: string, the job
--

redis.call('LREM', KEYS[1], 0, ARGV[1])
redis.call('SREM', KEYS[2], ARGV[1])

return nil
