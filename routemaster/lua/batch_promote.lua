--
-- Promote a batch from current to pending, ie. remove it as a reference
-- to its subscriber's "current" pointer.
--
-- KEYS[1]: set, the current refs for this subscriber
--
-- ARGV[1]: string, the batch UID
--
redis.call('SREM', KEYS[1], ARGV[1])
