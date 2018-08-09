-- local read = require 'read'
-- local readers = require 'readers'

-- local co_create = coroutine.create
-- local co_yield = coroutine.yield
-- local co_resume = coroutine.resume

-- local function parse(stream)
--    local l = 1
--    local c = 1

--    local read = co_create(read)
--    local reader = co_create(readers.body)

--    local ok, data = co_resume(read, reader)
--    local not_done, byte = co_resume(stream)

--    while ok and not_done do
--       if byte == 10 then
--          l = l + 1
--          c = 1
--       elseif byte ~= 13 then
--          c = c + 1
--       end

--       ok, data = co_resume(read, byte)
--       not_done, byte = co_resume(stream)
--       print(ok, data)
--       print(not_done, byte)
--       print('-')
--    end

--    if ok and not not_done then
--       ok, data = co_resume(read)
--    elseif not_done and data then
--       error(data)
--    elseif not_done then
--       c = c + 1
--    end

--    if ok then
--       return data
--    else
--       error(data .. ' at ' .. l .. ':' .. c, 0)
--    end
-- end

-- return parse
