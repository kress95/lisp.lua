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
-- helpers
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local inspect = require 'inspect'

local function puts(...)
   print(inspect(...))
   return ...
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- stream
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local stream = (function()
   local function from_string(str)
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

   return {
      from_string = from_string
   }
end)()

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- form
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local form = (function()
   local form_mt = {index={}}

   function form_mt:__tostring()
      local acc = {}
      local len = #self

      for i=1, len do
         acc[i] = tostring(self[i])
      end

      return '(' .. table.concat(acc, ' ') .. ')'
   end

   function form_mt.index:tail()
      local out = {}
      local len = #self

      for i=2, len do
         out[i - 1] = self[i]
      end

      return form(out)
   end

   local function form(tbl)
      local clone = {}

      for k,v in ipairs(tbl) do
         clone[k] = v
      end

      return setmetatable(clone, form_mt)
   end

   return setmetatable(form_mt, {
      __call = function (self, ...) return form(...) end,
   })
end)()

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- atom
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local atom = (function()
   local atom_mt = {}

   local function to_byte(char)
      return string.format("%X", string.byte(char))
   end

   local vararg = {}

   local function sanitize(value)
      if value == 'true' then return true, false
      elseif value == 'false' then return false, false
      elseif value == 'nil' then return nil, false
      elseif value == '...' then return vararg, false end

      local number = tonumber(value)
      if number then return number, false end

      local new_value = string.gsub(value, "[^%w]", to_byte)
      if new_value ~= value then
         value = 'g_g_' .. new_value
      end

      return value, true
   end

   local function atom(origin, symbol, source_map)
      if getmetatable(origin) == atom_mt then
         return atom(
            origin.g_g_origin,
            symbol or origin.g_g_symbol,
            source_map or origin.g_g_source_map
         )
      end

      if type(symbol) == 'table' then
         source_map = symbol
         symbol = false
      elseif source_map == nil then
         local info = debug.getinfo(2)

         source_map = {
            source = string.sub(info.source, 2),
            line = info.currentline,
            column = -1,
         }
      end

      local value = origin

      if symbol and type(origin) == 'string' then
         if string.sub(origin, 1, 4) == 'g_g_' then
            error("cannot define symbolic atoms with 'g_g_' prefixes", 2)
         end

         value, symbol = sanitize(origin)
      end

      return setmetatable({
         g_g_raw = value,
         g_g_origin = origin,
         g_g_symbol = symbol or false,
         g_g_source_map = source_map
      }, atom_mt)
   end

   function atom_mt.__index(self, k) return rawget(self, 'g_g_raw')[k] end
   function atom_mt.__newindex(self, k, v) rawget(self, 'g_g_raw')[k] = v end
   function atom_mt.__tostring(self) return tostring(rawget(self, 'g_g_raw')) end
   function atom_mt.__len(self) return #rawget(self, 'g_g_raw') end
   function atom_mt.__pairs(self) return pairs(rawget(self, 'g_g_raw')) end
   function atom_mt.__ipairs(self) return ipairs(rawget(self, 'g_g_raw')) end
   function atom_mt.__unm(self) return atom(-rawget(self, 'g_g_raw')) end

   function atom_mt.__add(left, right)
      if getmetatable(left) == getmetatable(right) then
         return atom(rawget(left, 'g_g_raw') + rawget(right, 'g_g_raw'))
      else
         return atom(rawget(left, 'g_g_raw') + right)
      end
   end

   function atom_mt.__sub(left, right)
      if getmetatable(left) == getmetatable(right) then
         return atom(rawget(left, 'g_g_raw') - rawget(right, 'g_g_raw'))
      else
         return atom(rawget(left, 'g_g_raw') - right)
      end
   end

   function atom_mt.__mul(left, right)
      if getmetatable(left) == getmetatable(right) then
         return atom(rawget(left, 'g_g_raw') * rawget(right, 'g_g_raw'))
      else
         return atom(rawget(left, 'g_g_raw') * right)
      end
   end

   function atom_mt.__div(left, right)
      if getmetatable(left) == getmetatable(right) then
         return atom(rawget(left, 'g_g_raw') / rawget(right, 'g_g_raw'))
      else
         return atom(rawget(left, 'g_g_raw') / right)
      end
   end

   function atom_mt.__mod(left, right)
      if getmetatable(left) == getmetatable(right) then
         return atom(rawget(left, 'g_g_raw') % rawget(right, 'g_g_raw'))
      else
         return atom(rawget(left, 'g_g_raw') % right)
      end
   end

   function atom_mt.__pow(left, right)
      if getmetatable(left) == getmetatable(right) then
         return atom(rawget(left, 'g_g_raw') ^ rawget(right, 'g_g_raw'))
      else
         return atom(rawget(left, 'g_g_raw') ^ right)
      end
   end

   function atom_mt.__concat(left, right)
      if getmetatable(left) == getmetatable(right) then
         return atom(rawget(left, 'g_g_raw') .. rawget(right, 'g_g_raw'))
      else
         return atom(rawget(left, 'g_g_raw') .. right)
      end
   end

   function atom_mt.__eq(left, right)
      return atom(rawget(left, 'g_g_raw') == rawget(right, 'g_g_raw'))
   end

   function atom_mt.__lt(left, right)
      return atom(rawget(left, 'g_g_raw') < rawget(right, 'g_g_raw'))
   end

   function atom_mt.__le(left, right)
      return atom(rawget(left, 'g_g_raw') <= rawget(right, 'g_g_raw'))
   end

   return setmetatable(atom_mt, {
      __call = function (self, ...) return atom(...) end,
   })
end)()

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- read
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local function read(stream, readtable)
   for char in stream do
      local reader = readtable[char]

      if reader then
         local result = reader(readtable, stream, char)
         if result then return result end
      else
         local buffer = {char}

         for char in stream do
            if readtable[char] then
               stream(-1)
               break
            end

            table.insert(buffer, char)
         end

         -- TODO: add debug data
         return atom(string.char(unpack(buffer)), true)
      end
   end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- readtable
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local readtable = (function()
   local function ignore()
   end

   local function comment(readtable, stream, char)
      for char in stream do
         if char == 10 then
            stream(-1)
            break
         end
      end
   end

   local function form_for(open_char, close_char)
      return function(readtable, stream, char)
         local form = form {}

         for char in stream do
            if char == close_char then return form end
            stream(-1)
            table.insert(form, read(stream, readtable))
         end

         error('wtf expected close delim '  .. string.char(close_char))
      end
   end

   local function form_error_for(close_char)
      return function(readtable, stream, char)
         error('wtf unexpected close delim ' .. string.char(close_char))
      end
   end

   local function string_for(boundary_char)
      return function(readtable, stream, char)
         local buffer = {}
         local prev = boundary_char

         for char in stream do
            if char == boundary_char and prev ~= 92 then break end
            table.insert(buffer, char)
            prev = char
         end

         return string.char(unpack(buffer))
      end
   end

   local function quote(readtable, stream, char)
      local atom = atom_create('symbol', 'quote')
      local data = read(stream, readtable)
      return form {atom, data}
   end

   local function quasiquote(readtable, stream, char)
      local atom = atom_create('symbol', 'quasiquote')
      local data = read(stream, readtable)
      return form {atom, data}
   end

   local function unquote_and_unquote_splicing(readtable, stream, char)
      if stream() == 64 then
         local atom = atom_create('symbol', '___unquote2Dsplicing')
         local data = read(stream, readtable)
         return form{atom, data}
      else
         stream(-1)
         local atom = atom_create('symbol', 'unquote')
         local data = read(stream, readtable)
         return form{atom, data}
      end
   end

   return {
      -- whitespaces
      [9] = ignore,
      [10] = ignore,
      [13] = ignore,
      [32] = ignore,

      -- comments
      [59] = comment,

      -- parens
      [40] = form_for(40, 41),
      [41] = form_error_for(41),

      -- square brackets
      [91] = form_for(91, 93),
      [93] = form_error_for(93),

      -- curly brackets
      [123] = form_for(123, 125),
      [125] = form_error_for(125),

      -- strings
      [34] = string_for(34),

      -- quote, quasiquote and unquote/unquote-splicing
      [39] = quote,
      [96] = quasiquote,
      [44] = unquote_and_unquote_splicing
   }
end)()

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- parse
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local function parse(stream)
   local ast = form {}

   repeat
      local item = read(stream, readtable)
      table.insert(ast, item)
   until item == nil

   return ast
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- macros
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local macros = (function()
   return {}
end)()

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- compiler
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -


-- at
-- op
-- local op = { add = " + ",
--              sub = " - ",
--              mul = " * ",
--              idiv = " // ",
--              div = " / ",
--              mod = " % ",
--              pow = " ^ ",
--              concat = " .. ",
--              eq = " == ",
--              lt = " < ",
--              le = " <= ",
--              bor = "|",
--              bxor = "~",
--              band = "&",
--              shl = "<<",
--              shr = ">>",
--              ["and"] = " and ",
--              ["or"] = " or ",
--              ["not"] = "not ",
--              unm = "-",
--              bnot = "~",
--              len = "#" }
-- do
-- set
-- while
-- repeat until
-- if
-- fornum
-- forin
-- local
-- goto
-- label
-- return
-- break
-- call
-- invoke
-- interface

local function compile(ast)

end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- -- evaluator
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

-- function eval()
-- end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local stream = stream.from_string [==[
(print "hello world")
]==]

local form = compile(parse(stream))
print(form)
