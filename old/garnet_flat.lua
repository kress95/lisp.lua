local inspect = require 'inspect'
local array = require 'array'

local function puts(...)
   print(inspect(...))
   return ...
end

-- ----------------------------------------------------------------------------
-- locals and helpers
-- ----------------------------------------------------------------------------

local unpack = unpack
local array_create = array.create
local array_push = array.__index.push
local array_pop = array.__index.pop
local string_byte = string.byte
local string_char = string.char
local string_format = string.format
local string_gsub = string.gsub
local io_open = io.open
local io_read = io.read
local co_create = coroutine.create
local co_resume = coroutine.resume
local yield = coroutine.yield

local function spawn(cofn, ...)
   local co = co_create(cofn)
   local ok, err = co_resume(co, ...)

   if not ok then
      error(err, 2)
   else
      return co
   end
end

local function resume(co, ...)
   local ok, a, b, c, d, e, f = co_resume(co, ...)

   if not ok and a then
      error(a, 2)
   end

   return a, b, c, d, e, f
end

-- ----------------------------------------------------------------------------
-- readtable
-- ----------------------------------------------------------------------------

local readtable = {
   -- reader to capture opened parens
   [40] = function(stream)
      yield('form', 'paren', true)
   end,

   -- reader to capture closed parens
   [41] = function(stream)
      yield('form', 'paren', false)
   end,

   -- reader to capture comments
   [59] = function(stream)
      for char in resume, stream do
         if char == 10 then break end
      end
   end,

   -- reader to capture double ticks
   [34] = function(stream, char)
      local prev = char
      local buffer = array_create {}

      for char in resume, stream do
         if char == 34 and prev ~= 92 then
            local str = string_char(unpack(buffer))
            yield('string', str)
            return
         else
            array_push(buffer, char)
            prev = char
         end
      end

      error('wtf')
   end,
}

-- ----------------------------------------------------------------------------
-- reader
-- ----------------------------------------------------------------------------

local function to_byte(char)
	return string_format("%X", string_byte(char))
end

local function sanitize(literal)
   local sanitized = string_gsub(literal,"[^%w]", to_byte)

   if sanitized ~= literal then
      return '____' .. sanitized
   else
      return literal
   end
end

local function tokenize(buffer)
   local literal = string_char(unpack(buffer))

   if literal == 'true' then
      yield('value', 'true')
      return
   end

   if literal == 'false' then
      yield('value', 'false')
      return
   end

   if literal == 'nil' then
      yield('value', 'nil')
      return
   end

   local decimal = tonumber(literal, 10)
   if decimal then
      yield('value', literal)
      return
   end

   local numeric = tonumber(literal)
   if decimal then
      yield('value', tostring(numeric))
      return
   end

   yield('symbol', sanitize(literal))
end

local function is_whitespace(c)
   return c == 9 or c == 10 or c == 13 or c == 32
end

local function reader(stream)
   yield()

   local buffer

   for char in resume, stream do
      local reader = readtable[char]
      local is_wpc = is_whitespace(char)

      if buffer and (is_wpc or reader) then
         tokenize(buffer)
         buffer = nil
      end

      if reader then
         reader(stream, char)
      elseif not is_wpc then
         if buffer == nil then
            buffer = array_create {char}
         else
            array_push(buffer, char)
         end
      end
   end
end

local function read(stream)
   local form = array_create {}
   local nest = array_create {}
   local depth = array_create {}

   local reader = spawn(reader, stream)

   for name, value, status in resume, reader do
      if name == 'form' then
         if status then
            local new_form = array_create {}

            array_push(form, new_form)
            array_push(nest, form)
            array_push(depth, value)

            form = new_form
         else
            local prev_value = array_pop(depth)

            if prev_value == nil then
               print('wtf1')
            elseif value ~= prev_value then
               print('wtf2')
            end

            form:to_table()
            form = array_pop(nest)
         end
      else
         array_push(form, {name, value})
      end
   end

   return form:to_table()
end

-- ----------------------------------------------------------------------------
-- stream functions
-- ----------------------------------------------------------------------------

local function stream_from_string(str)
   local index = 0
   local length = #str

   yield()

   for i=1, length do
      yield(string_byte(str, i))
   end
end

local function stream_from_file(path)
   local file = assert(io_open(path, 'r'))

   yield()

   while true do
      local char = io_read(file, 1)

      if char == nil then
         break
      else
         yield(char)
      end
   end
end

-- ----------------------------------------------------------------------------
-- test
-- ----------------------------------------------------------------------------

local stream = spawn(stream_from_string, [[
; test
"str\"ign"
]])
local form = read(stream)

print(form[1][2])

-- ----------------------------------------------------------------------------
-- module
-- ----------------------------------------------------------------------------

return {
   stream_from_string = stream_from_string,
   stream_from_file = stream_from_file,
   read = read,
   readtable = readtable,
}
