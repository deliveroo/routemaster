--
-- Dummy script for testing purposes
--
-- Returns sum of the arguments it was passed
--

local result = 0
for k,v in pairs(ARGV) do
  result = result + tonumber(v)
end
return result
