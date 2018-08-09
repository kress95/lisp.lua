-- local inspect = require 'inspect'
-- local array = require 'array'
-- local create = coroutine.create
-- local yield = coroutine.yield
-- local resume = coroutine.resume

-- local function puts(...)
--    print(inspect(...))
--    return ...
-- end

-- local function spawn(f, ...)
--    local co = create(f)
--    local state, msg = resume(co, ...)

--    if not state then
--       error(msg, 2)
--    else
--       return co
--    end
-- end

-- local function is_whitespace(byte)
--    return byte == 9 or byte == 10 or byte == 13 or byte == 32
-- end

-- local function read(readtable)
--    yield()

--    repeat
--       local byte, meta = yield()

--       if byte == 40 then
--          yield(true)
--       elseif byte == 41 then
--          yield(false)
--       elseif byte == 59 then
--          repeat byte = yield() until byte == 10 or byte == nil
--       elseif readtable and readtable[byte] then
--          local co = spawn(readtable[byte], readtable)
--          repeat local continue = resume(co) until not continue
--       elseif byte and not is_whitespace(byte) then
--          local acc, lbeg, lend = array.create {byte}, meta, meta

--          repeat
--             lend, byte, meta = meta, yield()

--             if byte == 40 then
--                yield(true)
--                break
--             elseif byte == 41 then
--                yield(false)
--                break
--             elseif byte == 59 then
--                repeat byte = yield() until byte == 10 or byte == nil
--             elseif is_whitespace(byte) then
--                break
--             elseif byte then
--                acc:push(byte)
--             end
--          until byte == nil

--          if #acc > 0 then
--             yield(string.char(unpack(acc)), lbeg, lend)
--          end
--       end
--    until byte == nil
-- end

-- local function parse(source, readtable)
--    local form, forms, delims = array.create {}, array.create {}, 0
--    local reader = spawn(read, readtable)

--    yield()

--    local ok, data = true
--    local cont, byte, meta = true

--    repeat
--       if data == true then
--          data = nil
--          local new_form = array.create {}

--          form:push(new_form)
--          forms:push(form)
--          form = new_form

--          delims = delims + 1
--       elseif data == false then
--          data = nil
--          delims = delims - 1

--          if delims < 0 then
--             error("unexpected 'close' delimiter", 0)
--             return
--          end

--          form:to_table()
--          form = forms:last()
--          forms:pop()
--       elseif data then
--          form:push(data)
--          data = nil
--       else
--          -- byte may be nil, it's a valid EOF/EOS signal for the reader
--          cont, byte, meta = resume(source)
--          ok, data = resume(reader, byte, meta)
--          print(ok, data)
--       end
--    until not ok or not cont

--    if delims > 0 then
--       error("expected 'close' delimiter", 0)
--       return
--    end

--    yield((forms[1] or form):to_table())
-- end

-- local function string_source(str)
--    local l, c = 1, 1
--    local length = #str

--    yield()

--    for i=1, length do
--       local byte = string.byte(str, i)

--       if byte == 10 then
--          l, c = l + 1, 1
--       elseif byte and byte ~= 13 then
--          c = c + 1
--       end

--       yield(byte, {l, c, 'in-memory'})
--    end

--    yield(nil, {l + 1, 1, 'in-memory'})
-- end

-- local src = spawn(string_source, [[
-- (())
-- ]])

-- local parser = spawn(parse, src, {})

-- repeat
--    local ok, data = coroutine.resume(parser)
--    print(ok)
--    puts(data)
-- until not ok
