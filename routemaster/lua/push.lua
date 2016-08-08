--
-- Pushes a message into multiple queues
--
-- KEYS[2n+1]:    list of new message UUIDs
-- KEYS[2n+2]:  hash of UUIDs -> payloads
-- ARGV[1]:     number of queues
-- ARGV[2]:     message UID
-- ARGV[3]:     message payload
--
for n = 1, tonumber(ARGV[1]) do
  redis.call('HSET', KEYS[2*n], ARGV[2], ARGV[3])
  redis.call('LPUSH', KEYS[2*n-1], ARGV[2]) 
end

