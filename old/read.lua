-- local array = require 'array'
-- local co_create = coroutine.create
-- local co_resume = coroutine.resume
-- local co_yield = coroutine.yield

-- -- messages sent from read to parse

-- function next_byte()
--    return co_yield()
-- end

-- function result(ast)
--    return co_yield(ast)
-- end

-- -- read

-- local function read(reader)
--    local delimiters = 0

--    local form = array.create {}
--    local forms = array.create {}
--    local readers = array.create {reader}

--    local ok, msg, data = co_resume(reader)

--    while ok do
--       if msg == 'next_byte' then
--          local byte, metadata = next_byte()
--          ok, msg, data = co_resume(reader, byte, metadata)

--          if not byte then
--             break
--          end
--       elseif msg == 'push_reader' then
--          reader = data.co
--          readers:push(reader)
--          ok, msg, data = unpack(data)
--       elseif msg == 'goto_reader' then
--          reader = data.co
--          ok, msg, data = unpack(data)
--       else
--          if msg == 'literal' then
--             form:push(data)
--          elseif msg == 'delimiter' then
--             if data then
--                local new_form = array.create {}

--                form:push(new_form)
--                forms:push(form)
--                form = new_form

--                delimiters = delimiters + 1
--             else
--                delimiters = delimiters - 1

--                if delimiters < 0 then
--                   error("unexpected 'close' delimiter", 0)
--                   return
--                end

--                form:to_table()
--                form = forms:last()
--                forms:pop()
--             end

--          elseif msg == 'pop_reader' then
--             readers:pop()
--             reader = readers:last()
--          elseif msg == 'syntax_error' then
--             error(data)
--             return
--          else
--             error('unexpected reader state', 0)
--          end

--          ok, msg, data = co_resume(reader, byte)
--       end
--    end

--    if delimiters > 0 then
--       error("expected 'close' delimiter", 0)
--       return
--    end

--    result((forms[1] or form):to_table())
-- end

-- return read
