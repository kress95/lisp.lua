-- Garnet Mini Lisp
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- author:                                      Christian Ferraz Lemos de Sousa
-- email:                                            cferraz95[AT]gmail[DOT]com
-- version:                                                               0.0.1
-- license:                                                              GLWTPL
-------------------------------------------------------------------------------

-- block globals (useful for debug)
setmetatable(_G, {
   __index = function(_G, key)
      error('variable ' .. key .. ' is not declared', 2)
   end,
   __newindex = function(_G, key, value)
      error('declaring global ' .. key .. ' to ' .. tostring(value), 2)
   end,
})

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
      __tostring = function(self)
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

-- local literal do
--    local function to_byte(char)
--       return string.format("%X", string.byte(char))
--    end

--    local function sanitize(str)
--       if str == 'true' then
--          return 'literal', 'true'
--       end

--       if str == 'false' then
--          return 'literal', 'false'
--       end

--       if str == 'nil' then
--          return 'literal', 'nil'
--       end

--       local decimal = tonumber(str, 10)
--       if decimal then
--          return 'literal', str
--       end

--       local numeric = tonumber(str)
--       if decimal then
--          return 'literal', tostring(numeric)
--       end

--       local symbol = string.gsub(str, "[^%w]", to_byte)
--       if symbol ~= str then
--          return 'symbol', '___' .. symbol
--       else
--          return 'symbol', str
--       end
--    end

--    function literal(buffer)
--       local literal = string.char(unpack(buffer))
--       return atom_create(sanitize(literal))
--    end
-- end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- public api
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local from_string
local from_file
local readtable
local read
local parse
local macros
local compile
local eval

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- streaming
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

function from_string(str)
   local idx, len = 0, #str

   return function(move)
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
-- atom
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local atom = {__tostring = function (self) return self[1] end}
local atom_cache = setmetatable({}, {__mode='v'})

local function to_byte(char)
   return string.format("%X", string.byte(char))
end

local function literal(name)
   local got = atom_cache[name]
   if got then return got end

   got = setmetatable({name, 'literal'}, atom)
   atom_cache[name] = got
   return got
end

local function symbol(name)
   local name2 = string.gsub(name, "[^%w]", to_byte)
   if name2 ~= name then name = '___' .. name2 end

   local got = atom_cache[name]
   if got then return got end

   got = setmetatable({name, 'symbol'}, atom)
   atom_cache[name] = got
   return got
end

local function atom(buffer)
   local lit = string.char(unpack(buffer))

   if lit == 'true' or lit == 'false' or lit == 'nil' then
      return literal(lit)
   end

   local decimal = tonumber(lit, 10)
   if decimal then return literal(lit) end

   local numeric = tonumber(lit)
   if numeric then return literal(tostring(numeric)) end


   return symbol(lit)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- readtable
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

do
   local function noop() end

   local function read_form(open_char, close_char)
      return function(stream)
         local form = array_create {}

         for char in stream do
            if char == close_char then return form end
            stream(-1)
            array_push(form, read(stream))
         end

         error('wtf expected close delim '  .. string.char(close_char))
      end
   end

   local function unbalanced_form(close_char)
      return function()
         error('wtf unexpected close delim ' .. string.char(close_char))
      end
   end

   readtable = {
      -- whitespaces
      [9] = noop, [10] = noop, [13] = noop, [32] = noop,

      -- parens
      [40] = read_form(40, 41), [41] = unbalanced_form(41),

      -- square brackets
      [91] = read_form(91, 93), [93] = unbalanced_form(93),

      -- curly brackets
      [123] = read_form(123, 125), [125] = unbalanced_form(125),

      -- comments
      [59] = function(stream)
         for char in stream do
            if char == 10 then
               stream(-1)
               break
            end
         end
      end,

      -- string support
      [34] = function(stream)
         local buffer = array_create {}
         local prev = 34

         for char in stream do
            if char == 34 and prev ~= 92 then break end
            array_push(buffer, char)
            prev = char
         end

         return string.char(unpack(buffer))
      end,

      -- quote
      [39] = function(stream)
         local atom = atom_create('symbol', 'quote')
         local data = read(stream)
         return array_create{atom, data}
      end,

      -- quasiquote support
      [96] = function(stream)
         local atom = atom_create('symbol', 'quasiquote')
         local data = read(stream)
         return array_create{atom, data}
      end,

      -- unquote/unquote-splicing
      [44] = function(stream)
         local char = stream()

         if char == 64 then
            local atom = atom_create('symbol', '___unquote2Dsplicing')
            local data = read(stream)
            return array_create{atom, data}
         else
            stream(-1)
            local atom = atom_create('symbol', 'unquote')
            local data = read(stream)
            return array_create{atom, data}
         end
      end
   }
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- read
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

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

         return atom(buffer)
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

do
   macros = {}
end

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
(print (unquote "splicing"))
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
