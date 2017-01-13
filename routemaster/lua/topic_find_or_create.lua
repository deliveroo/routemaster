--
-- Create a topic if it doesn't exist.
-- If a publisher is specified, and the topic doesn't exist or doesn't currently
-- have a publisher, it will be set.
--
-- Returns an array of:
-- * number of topics created
-- * number of topics claimed by a publisher
-- * the name of the topic's publisher.
--
-- KEYS[1]: set, the index
-- KEYS[2]: hash, the topic's metadata (may not exist)
--
-- ARGV[1]: topic name
-- ARGV[2]: publisher name(optional)
--

local added = redis.call('SADD', KEYS[1], ARGV[1])
local claimed = 0

if ARGV[2] and #ARGV[2] > 0 then
  claimed = redis.call('HSETNX', KEYS[2], 'publisher', ARGV[2])

  if claimed > 0 then
    return { added, 1, ARGV[2] }
  end
end

return { added, claimed, redis.call('HGET', KEYS[2], 'publisher') }
