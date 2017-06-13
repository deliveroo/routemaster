--
-- Pops jobs from a worker pending queue,
-- and re-adds them to the main queue if they're not already 
-- in the index.
--
-- KEYS[1]: list, the worker queue
-- KEYS[2]: list, the job queue
-- KEYS[3]: set,  the job index
-- KEYS[4]: set,  the queue's worker/pending index
--
-- ARGV[1]: the worker ID
--

local counter = 0
while true do
  local item = redis.call('RPOPLPUSH', KEYS[1], KEYS[2])
  if not item then break end
  counter = counter + 1
end

redis.call('SREM', KEYS[4], ARGV[1])

return counter

