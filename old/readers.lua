-- local array = require 'array'
-- local co_create = coroutine.create
-- local co_yield = coroutine.yield
-- local co_resume = coroutine.resume
-- local to_string = string.char

-- -- messages sent from readers to read

-- local function next_byte()
--    return co_yield('next_byte')
-- end

-- local function literal(arr)
--    return co_yield('literal', to_string(unpack(arr)))
-- end

-- local function delimiter(value)
--    return co_yield('delimiter', value)
-- end

-- local function push_reader(reader, ...)
--    local co = co_create(reader)
--    return co_yield('push_reader', {co = co, co_resume(co, ...)})
-- end

-- local function goto_reader(reader, ...)
--    local co = co_create(reader)
--    return co_yield('goto_reader', {co = co, co_resume(co, ...)})
-- end

-- local function pop_reader()
--    return co_yield('pop_reader')
-- end

-- -- readers

-- local readers = {}

-- function readers.comment()
--    while true do
--       local byte = next_byte()

--       if byte == nil or byte == 10 then
--          pop_reader()
--       end
--    end
-- end

-- function readers.literal(byte, meta)
--    local acc = array.create {meta=meta, byte}

--    while true do
--       byte = next_byte()

--       if byte then
--          if byte == 9 then
--             error('unexpected tabular space')
--          elseif byte == 40 then
--             literal(acc)
--             delimiter(true)
--             pop_reader()
--          elseif byte == 41 then
--             literal(acc)
--             delimiter(false)
--             pop_reader()
--          elseif byte == 59 then
--             literal(acc)
--             goto_reader(readers.comment)
--          elseif byte == 10 or byte == 13 or byte == 32 then
--             literal(acc)
--             pop_reader()
--          else
--             acc:push(byte)
--          end
--       else
--          literal(acc)
--          pop_reader()
--       end
--    end
-- end

-- function readers.body()
--    while true do
--       local byte = next_byte()

--       if byte then
--          if byte == 9 then
--             error('unexpected tabular space')
--          elseif byte == 40 then
--             read.msg.delimiter(true, meta)
--          elseif byte == 41 then
--             read.msg.delimiter(false)
--          elseif byte == 59 then
--             read.msg.push_reader(readers.comment)
--          elseif not (byte == 10 or byte == 13 or byte == 32) then
--             read.msg.push_reader(readers.literal, byte)
--          end
--       else
--          read.msg.pop_reader()
--       end
--    end
-- end

-- return readers
