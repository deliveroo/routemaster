-- 
-- Add a message to a batch, creating a new batch as required.
-- Automatically promote the batch if full after ingestion.
-- Increment batch and event counters as appropriate.
--
-- KEYS[1]: set,  the subscriber's current ref. should contain the batch UID if
--                specified otherwise indicates the batch was promoted, or deleted.
-- KEYS[2]: list, the batch payload.
-- KEYS[3]: list, the alt batch payload (empty initially, used if a new batch
--                must be created)
-- KEYS[4]: zset, the batch index
-- KEYS[5]: hash, the batch counters
-- KEYS[6]: hash, the event counters
--
-- ARGV[1]: the current batch UID. May be an empty string if there was no
--          current batch when calling this script.
-- ARGV[2]: the alt batch UID, used if a new batch must be created.
-- ARGV[3]: the message data
-- ARGV[4]: the subscriber name
-- ARGV[5]: the batch prefix count (number of items excluding payloads)
-- ARGV[6]: the maximum batch size
-- ARGV[7]: the current timestamp
--

local batch_ref_key     = KEYS[1]
local batch_key         = KEYS[2]
local alt_batch_key     = KEYS[3]
local index_key         = KEYS[4]
local batch_counter_key = KEYS[5]
local event_counter_key = KEYS[6]

local batch_uid         = ARGV[1]
local alt_batch_uid     = ARGV[2]
local data              = ARGV[3]
local subscriber_name   = ARGV[4]
local prefix_count      = tonumber(ARGV[5])
local max_batch_size    = tonumber(ARGV[6])
local now               = ARGV[7]

-- if there was no current batch passed, or if the batch is no longer current, 
-- switch to creating a new batch (and marking it as current)
if batch_uid:len() == 0 or redis.call('SISMEMBER', batch_ref_key, batch_uid) < 1 then
  batch_uid = alt_batch_uid
  batch_key = alt_batch_key
  
  redis.call('SADD',    batch_ref_key, batch_uid)
  redis.call('ZADD',    index_key, now, batch_uid)
  redis.call('RPUSH',   batch_key, subscriber_name, now, 0)
  redis.call('HINCRBY', batch_counter_key, subscriber_name, 1)
end

-- add message data
redis.call('RPUSH',   batch_key, data)
redis.call('HINCRBY', event_counter_key, subscriber_name, 1)

-- promote batch if full
local batch_length = redis.call('LLEN', batch_key) - prefix_count
if batch_length >= max_batch_size then
  redis.call('SREM', batch_ref_key, batch_uid)
end  

return { batch_uid, batch_length }
