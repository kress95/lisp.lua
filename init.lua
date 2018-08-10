-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- helpers
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

setmetatable(_G, {
   __index = function(_G, key)
      error('variable ' .. key .. ' is not declared', 2)
   end,
   __newindex = function(_G, key, value)
      error('declaring global ' .. key .. ' to ' .. tostring(value), 2)
   end,
})

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

   local function from_file(path)
      local file = assert(io.open(path, 'r'))
      local idx = 0

      return function(move)
         move = move or 1
         idx = idx + move

         if move ~= 1 then file:seek('set', idx) end
         local char = file:read(1)
         if move ~= 1 then file:seek('set', idx) end
         if char then return string.byte(char, 1) end
      end
   end

   return {
      from_string = from_string,
      from_file = from_file
   }
end)()

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- atom
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local vararg = setmetatable({}, {__tostring = function() return '...' end})

local new_atom, atom = (function()
   -- helpers

   local function to_byte(char)
      if char == "_" then
         return char
      else
         return string.format("%X", string.byte(char))
      end
   end

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

   -- implementation

   local atom = {}

   local function new_atom(src, key, map) -- or (src, map)
      -- derive atom
      if getmetatable(src) == atom then
         return new_atom(src.g_g_src, key or src.g_g_key, map or src.g_g_map)
      end

      -- allows omiting key
      if type(key) == 'table' then
         map = key
         key = false
      elseif map == nil then
         local inf = debug.getinfo(2)
         map = {
            src = string.sub(inf.source, 2),
            lin = inf.currentline,
            col = -1,
         }
      end

      -- validate atom 'keyness'
      local raw = src
      if key and type(src) == 'string' then
         if string.sub(src, 1, 4) == 'g_g_' then
            error("cannot define keyic atoms with 'g_g_' prefixes", 2)
         end

         raw, key = sanitize(src)
      end

      -- return atom
      return setmetatable({
         g_g_raw = raw,
         g_g_src = src,
         g_g_key = key or false,
         g_g_map = map
      }, atom)
   end

   -- TODO: better error handling
   function atom.__index(self, k) return rawget(self, 'g_g_raw')[k] end
   function atom.__newindex(self, k, v) rawget(self, 'g_g_raw')[k] = v end
   function atom.__len(self) return #rawget(self, 'g_g_raw') end
   function atom.__pairs(self) return pairs(rawget(self, 'g_g_raw')) end
   function atom.__ipairs(self) return ipairs(rawget(self, 'g_g_raw')) end
   function atom.__unm(self) return new_atom(-rawget(self, 'g_g_raw')) end

   function atom.__tostring(self)
      local value = rawget(self, 'g_g_raw')

      if type(value) == 'string' and not self.g_g_key then
         return table.concat({'"', tostring(value), '"'}, '')
      else
         return tostring(value)
      end
   end

   function atom.__add(left, right)
      if getmetatable(left) == getmetatable(right) then
         return new_atom(rawget(left, 'g_g_raw') + rawget(right, 'g_g_raw'))
      else
         return new_atom(rawget(left, 'g_g_raw') + right)
      end
   end

   function atom.__sub(left, right)
      if getmetatable(left) == getmetatable(right) then
         return new_atom(rawget(left, 'g_g_raw') - rawget(right, 'g_g_raw'))
      else
         return new_atom(rawget(left, 'g_g_raw') - right)
      end
   end

   function atom.__mul(left, right)
      if getmetatable(left) == getmetatable(right) then
         return new_atom(rawget(left, 'g_g_raw') * rawget(right, 'g_g_raw'))
      else
         return new_atom(rawget(left, 'g_g_raw') * right)
      end
   end

   function atom.__div(left, right)
      if getmetatable(left) == getmetatable(right) then
         return new_atom(rawget(left, 'g_g_raw') / rawget(right, 'g_g_raw'))
      else
         return new_atom(rawget(left, 'g_g_raw') / right)
      end
   end

   function atom.__mod(left, right)
      if getmetatable(left) == getmetatable(right) then
         return new_atom(rawget(left, 'g_g_raw') % rawget(right, 'g_g_raw'))
      else
         return new_atom(rawget(left, 'g_g_raw') % right)
      end
   end

   function atom.__pow(left, right)
      if getmetatable(left) == getmetatable(right) then
         return new_atom(rawget(left, 'g_g_raw') ^ rawget(right, 'g_g_raw'))
      else
         return new_atom(rawget(left, 'g_g_raw') ^ right)
      end
   end

   function atom.__concat(left, right)
      if getmetatable(left) == getmetatable(right) then
         return new_atom(rawget(left, 'g_g_raw') .. rawget(right, 'g_g_raw'))
      else
         return new_atom(rawget(left, 'g_g_raw') .. right)
      end
   end

   function atom.__eq(left, right)
      return new_atom(rawget(left, 'g_g_raw') == rawget(right, 'g_g_raw'))
   end

   function atom.__lt(left, right)
      return new_atom(rawget(left, 'g_g_raw') < rawget(right, 'g_g_raw'))
   end

   function atom.__le(left, right)
      return new_atom(rawget(left, 'g_g_raw') <= rawget(right, 'g_g_raw'))
   end

   function atom.deref(atom)
      return rawget(atom, 'g_g_raw')
   end

   return new_atom, atom
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
         local buf = {char}

         for char in stream do
            if readtable[char] then
               stream(-1)
               break
            end

            table.insert(buf, char)
         end

         return new_atom(string.char(unpack(buf)), true)
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
         local form = {}

         for char in stream do
            if char == close_char then
               return form
            else
               local reader = readtable[char]

               if reader then
                  local result = reader(readtable, stream, char)
                  if result then table.insert(form, result) end
               else
                  stream(-1)
                  table.insert(form, read(stream, readtable))
               end
            end
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

         return new_atom(string.char(unpack(buffer)))
      end
   end

   local function quote(readtable, stream, char)
      local atom = new_atom('quote', true)
      local data = read(stream, readtable)
      return {atom, data}
   end

   local function quasiquote(readtable, stream, char)
      local atom = new_atom('quasiquote', true)
      local data = read(stream, readtable)
      return {atom, data}
   end

   local function unquote_and_unquote_splicing(readtable, stream, char)
      if stream() == 64 then
         local atom = new_atom('___unquote2Dsplicing', true)
         local data = read(stream, readtable)
         return {atom, data}
      else
         stream(-1)
         local atom = new_atom('unquote', true)
         local data = read(stream, readtable)
         return {atom, data}
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
   local ast = {}

   repeat
      local item = read(stream, readtable)
      table.insert(ast, item)
   until item == nil

   return ast
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- compiler (messy)
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local compile = (function()
   local xprt, xpr, xprs = {}
   local stmt, stm, stms = {}

   -- helpers

   local function tail(arr, idx)
      return {select((idx or 1) + 1, unpack(arr))}
   end

   local function flatten(arr)
      local buf, idx, len = {}, 0, #arr

      for i=1, len do
         local item = arr[i]

         if type(item) == 'table' and getmetatable(item) ~= atom then
            local arr2 = flatten(item)
            local len2 = #arr2

            for i=1, len2 do
               idx = idx + 1
               buf[idx] = arr2[i]
            end
         else
            idx = idx + 1
            buf[idx] = item
         end
      end

      return buf
   end

   local function indent(depth)
      local buf = {}
      for i=1, depth do buf[i] = '   ' end
      return buf
   end

   local function args(form)
      local buf, idx, len = {form[1]}, 1, #form

      for i=2, len do
         idx = idx + 1
         buf[idx] = ', '

         idx = idx + 1
         buf[idx] = form[i]
      end

      return buf
   end

   local function call(form, depth)
      return {xpr(form[1]), '(', xprs(tail(form), depth + 1), ')'}
   end

   local function bin1(op)
      return function(form, depth)
         local left = form[2]
         local right = form[3]

         if left == nil or right == nil then
            error('wtf', 2)
         end

         local len = #form
         local buf = {}

         for i=4, len do table.insert(buf, '(') end

         table.insert(buf, xpr(left, depth))
         table.insert(buf, op)
         table.insert(buf, xpr(right, depth))

         for i=4, len do
            table.insert(buf, ')')
            table.insert(buf, op)
            table.insert(buf, xpr(form[i], depth))
         end

         return buf
      end
   end

   local function bin2(op)
      return function(form, depth)
         local left = form[2]
         local right = form[3]

         if left == nil or right == nil then
            error('wtf', 2)
         end

         local len = #form
         local buf = {'('}

         table.insert(buf, xpr(left, depth))
         table.insert(buf, op)
         table.insert(buf, xpr(right, depth))

         for i=4, len do
            table.insert(buf, op)
            table.insert(buf, xpr(form[i], depth))
         end
         table.insert(buf, ')')

         return buf
      end
   end

   local function comp(op)
      return function(form, depth)
         local left = form[2]
         local right = form[3]

         if left == nil or right == nil then
            error('wtf', 2)
         end

         local len = #form
         local buf = {}

         table.insert(buf, xpr(left, depth))
         table.insert(buf, op)
         table.insert(buf, xpr(right, depth))

         for i=3, len do
            if i < len then
               table.insert(buf, ' and ')
               table.insert(buf, xpr(form[i], depth))
               table.insert(buf, op)
               table.insert(buf, xpr(form[i + 1], depth))
            end
         end

         return buf
      end
   end

   local function unop(op)
      return function(form, depth)
         return {'(', op, xpr(form[2], depth), ')'}
      end
   end

   -- expressions

   function xpr(form, depth)
      if getmetatable(form) == atom then
         return form
      elseif form then
         local head = form[1]

         if head then
            local name = atom.deref(head)
            local cxpr = xprt[name]

            if cxpr then
               return cxpr(form, depth)
            else
               return call(form, depth)
            end
         end
      end

      return {}
   end

   function xprs(arr, depth)
      if type(arr) == atom then
         return xpr(arr)
      else
         local buf, len = {xpr(arr[1], depth)}, #arr

         for i=2, len do
            table.insert(buf, ', ')
            table.insert(buf, xpr(arr[i], depth))
         end

         return buf
      end
   end

   xprt['function'] = function(form, depth)
      return {
         '(function(',
         args(form[2]),
         ')\n',
         stms(tail(form, 2), depth + 1),
         indent(depth - 1),
         'end)'
      }
   end

   xprt.table = function(form, depth)
      local len = #form
      local buf = {'{\n'}

      for i=2, len do
         table.insert(buf, indent(depth))

         local item = form[i]

         if getmetatable(item) ~= atom then
            if atom.deref(item[1]) == 'kv' then
               local key = item[2]
               local val = item[3]

               if key.g_g_key then
                  table.insert(buf, xpr(key, depth + 1))
                  table.insert(buf, ' = ')
               else
                  table.insert(buf, '[')
                  table.insert(buf, xpr(key, depth + 1))
                  table.insert(buf, '] = ')
               end

               table.insert(buf, xpr(val, depth))
            elseif atom.deref(item[1]) == 'xkv' then
               table.insert(buf, '[')
               table.insert(buf, xpr(item[2], depth + 1))
               table.insert(buf, '] = ')
               table.insert(buf, xpr(item[3], depth + 1))
            else
               table.insert(buf, xpr(item, depth + 1))
            end
         else
            table.insert(buf, xpr(item, depth + 1))
         end

         table.insert(buf, ',\n')
      end

      table.insert(buf, indent(depth - 1))
      table.insert(buf, '}')

      return buf
   end

   -- comparison operators
   xprt.g_g_2B = bin1(' + ')
   xprt.g_g_2A = bin1(' * ')
   xprt.g_g_2F = bin1(' / ')
   xprt.g_g_25 = bin1(' % ')
   xprt.g_g_5E = bin1(' ^ ')

   function xprt.g_g_2E(form, depth)
      local item = xpr(form[2], depth)
      local key = xpr(form[3], depth)

      if getmetatable(key) == atom and key.g_g_key then
         return {item, '.', key}
      else
         return {item, '[', key, ']'}
      end
   end

   function xprt.at(form, depth)
      return {xpr(form[2], depth), '[', xpr(form[3], depth), ']'}
   end

   function xprt.g_g_2E2E(form, depth)
      local first = form[2]

      if first == nil or form[3] == nil then
         error('wtf', 2)
      end

      local len = #form
      local buf = {}

      table.insert(buf, '(')
      table.insert(buf, '(')
      table.insert(buf, xpr(first, depth))
      table.insert(buf, ')')

      for i=3, len do
         table.insert(buf, ' .. ')
         table.insert(buf, '(')
         table.insert(buf, xpr(form[i], depth))
         table.insert(buf, ')')
      end

      table.insert(buf, ')')

      return buf
   end

   local xprt_sub = bin1(' - ')
   local xprt_unm = unop('-')

   function xprt.g_g_2D(form, depth)
      if #form  > 2 then
         return xprt_sub(form, depth)
      else
         return xprt_unm(form, depth)
      end
   end

   -- comparison operators
   xprt.g_g_3D3D = comp(' == ')
   xprt.g_g_3E = comp(' > ')
   xprt.g_g_3E3D = comp(' >= ')
   xprt.g_g_3C = comp(' < ')
   xprt.g_g_3C3D = comp(' <= ')
   xprt.g_g_7E3D = comp(' ~= ')

   -- bolean logic operators
   xprt['and'] = bin2(' and ')
   xprt['or'] = bin2(' or ')
   xprt['not'] = unop('not ')

   -- unary operators
   xprt.g_g_23 = unop('#')

   -- statements

   function stm(form, depth)
      local head = form[1]
      local name = atom.deref(head)
      local cstm = stmt[name]

      if cstm then
         return cstm(form, depth)
      else
         return call(form, depth)
      end
   end

   function stms(form, depth)
      local buf, len = {}, #form

      for i=1, len do
         table.insert(buf, indent(depth))
         table.insert(buf, stm(form[i], depth))
         table.insert(buf, '\n')
      end

      return buf
   end

   stmt.g_g_2E = xprt.g_g_2E
   stmt.at = xprt.at

   stmt['do'] = function(form, depth)
      return {
         'do\n',
         stms(tail(form), depth + 1),
         indent(depth),
         'end'
      }
   end

   function stmt.g_g_3D(form, depth)
      local rem = tail(form, 2)

      if getmetatable(form[2]) == atom then
         return {form[2], ' = ', xprs(rem, depth)}
      else
         return {stm(form[2], depth), ' = ', xprs(rem, depth)}
      end
   end

   stmt['local'] = function(form, depth)
      return {'local ', args(tail(form))}
   end

   stmt['while'] = function(form, depth)
      return {
         'while ',
         xpr(form[2], depth),
         ' do\n',
         stms(tail(form, 2), depth +  1),
         indent(depth),
         'end'
      }
   end

   stmt['repeat'] = function(form, depth)
      local body = tail(form)
      local unti = body[#body - 1]
      local cond = body[#body]

      assert(tostring(unti) == 'until', 'wtf man')

      body[#body] = nil
      body[#body] = nil

      return {
         'repeat\n',
         stms(body, depth + 1),
         indent(depth),
         unti,
         ' ',
         xpr(cond)
      }
   end

   stmt['return'] = function(form, depth)
      local rem = tail(form)

      if #rem > 0 then
         return {form[1], '(', xprs(tail(form), depth + 1), ')'}
      else
         return form[1]
      end
   end

   stmt['break'] = function(form, depth)
      return {form[1]}
   end

   stmt['goto'] = function(form, depth)
      return {form[1], ' ', form[2]}
   end

   stmt['label'] = function(form, depth)
      return {'::', form[2], '::'}
   end

   stmt['for'] = function(form, depth)
      local step = form[2][3]
      if step then
         return {
            'for ',
            form[2][1][1],
            '=',
            xpr(form[2][1][2], depth),
            ', ',
            xpr(form[2][2], depth),
            ', ',
            xpr(step, depth),
            ' do\n',
            stms(tail(form, 2), depth +  1),
            indent(depth),
            'end'
         }
      else
         return {
            'for ',
            form[2][1][1],
            '=',
            xpr(form[2][1][2], depth),
            ', ',
            xpr(form[2][2], depth),
            ' do\n',
            stms(tail(form, 2), depth +  1),
            indent(depth),
            'end'
         }
      end
   end

   function stmt.g_g_for2Din(form, depth)
      return {
         'for ',
         args(form[2]),
         ' in ',
         xprs(form[3], depth),
         ' do\n',
         stms(tail(form, 3), depth +  1),
         indent(depth),
         'end'
      }
   end

   stmt['if'] = function(form, depth)
      local len = #form
      local buf = {
         'if ',
         xpr(form[2][1], depth + 2),
         ' then\n',
         stms(tail(form[2]), depth + 1),
      }

      for i=3, len do
         table.insert(buf, indent(depth))

         if i == len and atom.deref(form[i][1]) == 'else' then
            table.insert(buf, 'else\n')
         else
            table.insert(buf, 'elseif ')
            table.insert(buf, xpr(form[i][1], depth + 2))
            table.insert(buf, ' then\n')
         end

         table.insert(buf, stms(tail(form[i]), depth + 1))
      end

      table.insert(buf, indent(depth))
      table.insert(buf, 'end')

      return buf
   end

   local function compile(ast)
      local buf = flatten(stms(ast, 0))
      local len = #buf
      for i=1, len do buf[i] = tostring(buf[i]) end
      return table.concat(buf, '')
   end

   return compile
end)()

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- test
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

local stream = stream.from_file 'lisp.lisp'

local form = parse(stream)
local file = assert(io.open('lisp.lua', 'w'))

file:write(tostring(compile(form)))
file:close()
