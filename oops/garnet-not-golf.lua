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
-- atom type
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local atom_mt do
   atom_mt = {
      __tostring = function (self)
         if self.type == 'string' then
            return '"' .. self.raw .. '"'
         else
            return self.raw
         end
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
-- helpers
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local inspect = require 'inspect'

local function puts(...)
   print(inspect(...))
   return ...
end

local literal do
   local function to_byte(char)
      return string.format("%X", string.byte(char))
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

      local symbol = string.gsub(str, "[^%w]", to_byte)
      if symbol ~= str then
         return 'symbol', '___' .. symbol
      else
         return 'symbol', str
      end
   end

   function literal(buffer)
      local literal = string.char(unpack(buffer))
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
-- streaming (ok)
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

function from_string(str)
   local idx, len = 0, #str

   return function (move)
      idx = idx + (move or 1)

      if idx > len then
         idx = len + 1
         return
      elseif idx < 1 then
         idx = 1
      end

      return string.byte(str, idx)
   end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- reader
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local readtable = {
   [9] = noop,
   [10] = noop,
   [13] = noop,
   [32] = noop,
}

do
   -- changes the readtable to ignore the following characters
   local function ignore(char, next_char, ...)
      readtable[char] = noop
      if next_char then ignore(next_char, ...) end
   end

   -- changes the readtable to use these characters as delimiters
   local function delimiter(open_char, close_char)
      local close = string.char(close_char)

      readtable[open_char] = function(stream)
         local form = array_create {}

         for char in stream do
            if char == close_char then break end
            stream(-1)
            array_push(form, read(stream))
         end

         return form
      end

      readtable[close_char] = function ()
         error('wtf unbalanced' .. close)
      end
   end

   -- apply readtable changes
   ignore(9, 10, 13, 32)
   delimiter(40, 41)
   delimiter(91, 93)
   delimiter(123, 125)

   -- comment support
   readtable[59] = function(stream)
      for char in stream do
         if char == 10 then
            stream(-1)
            break
         end
      end
   end

   -- string support
   readtable[34] = function(stream)
      local buffer = array_create {}
      local prev = 34

      for char in stream do
         if char == 34 and prev ~= 92 then
            break
         else
            array_push(buffer, char)
         end

         prev = char
      end

      local value = string.char(unpack(buffer))
      return atom_create('string', value)
   end

   -- quote support
   readtable[39] = function(stream)
      local atom = atom_create('symbol', 'quote')
      local data = read(stream)
      return array_create{atom, data}
   end

   -- unquote support
   readtable[44] = function(stream)
      local char = stream()

      if char == 64 then
         local atom = atom_create('symbol', 'unquote-splicing')
         local data = read(stream)
         return array_create{atom, data}
      else
         stream(-1)
         local atom = atom_create('symbol', 'unquote')
         local data = read(stream)
         return array_create{atom, data}
      end
   end

   -- quasiquote support
   readtable[96] = function(stream)
      local atom = atom_create('symbol', 'quasiquote')
      local data = read(stream)
      return array_create{atom, data}
   end
end

function read(stream)
   for char in stream do
      local reader = readtable[char]

      if reader then
         local result = reader(stream, char)
         if result then return result end
      else
         local buffer = array_create {char}

         for char in stream do
            if readtable[char] then
               stream(-1)
               break
            end

            array_push(buffer, char)
         end

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
(print '(za ,@"warudo" `kek))
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
