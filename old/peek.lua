-- Garnet Mini Lisp
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- author:                                      Christian Ferraz Lemos de Sousa
-- email:                                            cferraz95[AT]gmail[DOT]com
-- version:                                                               0.0.1
-- license:                                                              GLWTPL
-------------------------------------------------------------------------------

-- block globals (useful for debug)
setmetatable(_G, {
   __index = function (_G, key)
      error('variable ' .. key .. ' is not declared', 2)
   end,
   __newindex = function (_G, key, value)
      error('declaring global ' .. key .. ' to ' .. tostring(value), 2)
   end,
})

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- locals (ok)
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

-- metaprogramming
local unpack = unpack
local setmetatable = setmetatable
local getmetatable = getmetatable

-- coroutines
local coroutine_create = coroutine.create
local coroutine_status = coroutine.status
local coroutine_resume = coroutine.resume
local coroutine_yield = coroutine.yield

-- io
local io_open = io.open
local io_read = io.read

-- string
local string_byte = string.byte
local string_char = string.char
local string_format = string.format
local string_gsub = string.gsub

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- atom type
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local atom_mt do
   atom_mt = {
      __tostring = function (self)
         if self.type == 'literal' then
            return self.raw
         end

         -- string (TODO: format)
         return self.raw
      end
   }
end

local function atom_create(type, raw_value, from, to)
   return setmetatable({
      type = type,
      raw = raw_value,
      from = from,
      to = to
   }, atom_mt)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- array type (ok)
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local array_mt do
   local function next(self, idx)
      local len = self[0]

      while idx < len do
         idx = idx + 1

         local val = self[idx]

         if val ~= nil then
            return idx, self[idx]
         end
      end
   end

   array_mt = {
      __tostring = function (self)
         local acc = {}
         local len = self[0]

         for i=1, len do
            acc[i] = tostring(self[i])
         end

         return '(' .. table.concat(acc, ' ') .. ')'
      end,

      __len = function(self)
         return self[0]
      end,

      __ipairs = function(self)
         return next, self, 0
      end,
   }
end

local function array_create(tbl)
   tbl[0] = #tbl
   return setmetatable(tbl, array_mt)
end

local function array_head(self)
   return self[1]
end

local function array_tail(self)
   local out = {}
   local len = self[0]

   for i=2, len do
      out[i - 1] = self[i]
   end

   return array(out)
end

local function array_push(self, item)
   local len = self[0] + 1

   self[len] = item
   self[0] = len
end

local function array_pop(self, item)
   if self[0] > 0 then
      local len = self[0]
      local pop = self[len]

      self[len] = nil
      self[0] = len - 1

      return pop
   end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- coroutine type
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local co_yield = coroutine_yield

local function co_spawn(fn, ...)
   local co = coroutine_create(fn)
   local ok, err = coroutine_resume(co, ...)

   if not ok then
      error(err, 2)
   else
      return co
   end
end

local function co_step(co, ...)
   if coroutine_status(co) == 'suspended' then
      local ok, a, b, c, d, e, f = coroutine_resume(co, ...)

      if not ok and a then
         error(a, 2)
      end

      return a, b, c, d, e, f
   end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- helpers
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local inspect = require 'inspect'

local function puts(...)
   print(inspect(...))
   return ...
end

local literal do
   local function to_byte(char)
      return string_format("%X", string_byte(char))
   end

   local function sanitize(str)
      if str == 'true' then
         return 'literal', 'true'
      end

      if str == 'false' then
         return 'literal', 'false'
      end

      if str == 'nil' then
         return 'literal', 'nil'
      end

      local decimal = tonumber(str, 10)
      if decimal then
         return 'literal', str
      end

      local numeric = tonumber(str)
      if decimal then
         return 'literal', tostring(numeric)
      end

      local symbol = string_gsub(str, "[^%w]", to_byte)
      if symbol ~= str then
         return 'symbol', '___' .. symbol
      else
         return 'symbol', str
      end
   end

   function literal(buffer)
      local literal = string_char(unpack(buffer))
      return atom_create(sanitize(literal))
   end
end

local function noop()
end

local function is_whitespace(char)
   return char == 9 or char == 10 or char == 13 or char == 32
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- public api
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local from_string
local from_file
local read
local parse
local compile
local eval

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- streaming
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

function from_string(str)
   local idx, len = 0, #str

   return function ()
      idx = idx + 1

      if idx < len then
         if idx + 1 < len then
            return string_byte(str, idx), string_byte(str, idx + 1)
         else
            return string_byte(str, idx)
         end
      end
   end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- reader
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local readtable = {}

do
   -- changes the readtable to ignore the following characters
   local function ignore(char, next_char, ...)
      readtable[char] = noop
      if next_char then ignore(next_char, ...) end
   end

   -- changes the readtable to use these characters as delimiters
   local function delimiter(open_char, close_char)
      local close = string_char(close_char)

      readtable[open_char] = function(stream)
         local form = array_create {}

         for char in stream do
            -- print(char)
         --    array_push(form, read(stream))
         --    if char == close_char then break end
         end

         return form
      end

      readtable[close_char] = function ()
         error('wtf unbalanced' .. close)
      end
   end

   -- changes the readtable
   local comment do
      local function fn(stream)
         for char, next_char in stream do
            if char == 10 or next_char == 10 then
               break
            end
         end
      end

      function comment(char, next_char, ...)
         readtable[char] = fn
         if next_char then comment(next_char, ...) end
      end
   end

   ignore(9, 10, 13, 32)
   delimiter(40, 41)
   delimiter(91, 93)
   delimiter(123, 125)
   comment(59)
end

function read(stream)
   local buffer

   for char in stream do
      local reader = readtable[char]

      if reader then
         local result = reader(stream)
         if result then return result end
      elseif buffer then
         array_push(buffer, char)
      else
         buffer = array_create {char}
      end

      if buffer and readtable[next_char] then
         return literal(buffer)
      end
   end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- parser
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

function parse()
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- compiler
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local macros = {}

function compile()
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- evaluator
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

function eval()
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local stream = from_string [==[
(1 2 3)
]==]

local form = read(stream)

print(form)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- module
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

return {
   -- code streams
   from_string = from_string,
   from_file = from_file,

   -- read stage
   readtable = readtable,
   read = read,

   -- parsing stage
   parse = parse,

   -- compilation
   macros = macros,
   compile = compile,

   -- execution
   eval = eval,
}
