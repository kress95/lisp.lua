-- local co_create = coroutine.create
-- local co_yield = coroutine.yield
-- local co_resume = coroutine.resume

-- local function in_memory(str)
--    local i = 0
--    local length = #str

--    co_yield()

--    repeat
--       i = i + 1
--       co_yield(string.byte(str, i))
--    until i > length

--    co_yield()
-- end

-- local inspect = require 'inspect'
-- local function puts(...)
--    print(inspect(...))
--    return ...
-- end

-- local source = co_create(in_memory)

-- co_resume(source, [[
-- (local a 10)
-- ]])

-- local parse = require 'parse'

-- parse(source)


-- -- puts(result)

-- -- local result = input_string [[
-- --    (local a 10)
-- --    (print a)
-- --    (
-- -- ]]
-- -- local get_byte = string.byte
-- -- local function input_string(input)
-- --    local reader = co_create(read)
-- --    local parser = co_create(parse)
-- --    local i = 0
-- --    local l, c = 1, 1
-- --    local length = #input
-- --    local ok, data = co_resume(parser, reader)
-- --    while ok and i <= length do
-- --       i = i + 1
-- --       local byte = get_byte(input, i)
-- --       if byte == 10 then
-- --          l = l + 1
-- --          c = 1
-- --       elseif byte ~= 13 then
-- --          c = c + 1
-- --       end
-- --       ok, data = co_resume(parser, byte)
-- --    end
-- --    if ok then
-- --       ok, data = co_resume(parser)
-- --       if not ok then
-- --       end
-- --    end
-- --    if ok then
-- --       return data
-- --    else
-- --       error(data .. ' at ' .. l .. ':' .. c .. ' (in-memory)', 0)
-- --    end
-- -- end
