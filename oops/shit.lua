



   local function bin_for(op)
      return function(left, right, ...)
         if left == nil or right == nil then
            error('wtf', 2)
         end

         local rem = {...}
         local len = #rem
         local buf = {}

         for i=1, len do
            table.insert(buf, '(')
         end

         table.insert(buf, left)
         table.insert(buf, op)
         table.insert(buf, right)

         for i=1, len do
            table.insert(buf, ')')
            table.insert(buf, op)
            table.insert(buf, rem[i])
         end

         return buf
      end
   end

   local function bin2_for(op)
      local function recur(left, right, on, ...)
         if on then
            return {left, op, right, op, recur(on, ...)}
         else
            return {left, op, right}
         end
      end

      return recur
   end

   local function comp_for(op)
      local function recur(left, right, on, ...)
         if on then
            return {left, op, right, ' and ', recur(right, on, ...)}
         else
            return {left, op, right}
         end
      end

      return recur
   end

   local function unop_for(op)
      return function(value)
         return {'(', op, value, ')'}
      end
   end

   -- binary operators
   xpr.g_g_2B = bin_for(' + ')
   xpr.g_g_2D = bin_for(' - ')
   xpr.g_g_2A = bin_for(' * ')
   xpr.g_g_2F = bin_for(' / ')
   xpr.g_g_25 = bin_for(' % ')
   xpr.g_g_5E = bin_for(' ^ ')
   xpr.g_g_2E2E = bin_for(' .. ')

   -- comparison operators
   xpr.g_g_3D3D = comp_for(' == ')
   xpr.g_g_3E = comp_for(' > ')
   xpr.g_g_3E3D = comp_for(' >= ')
   xpr.g_g_3C = comp_for(' < ')
   xpr.g_g_3C3D = comp_for(' <= ')
   xpr.g_g_7E3D = comp_for(' ~= ')

   -- bolean logic operators
   xpr['and'] = bin2_for(' and ')
   xpr['or'] = bin2_for(' or ')
   xpr['not'] = unop_for('not ')

   -- unary operators
   xpr.g_g_23 = unop_for('#')

   local sub = xpr.g_g_2D
   local unm = unop_for('-')

   xpr.g_g_2D = function(left, right, ...)
      if right then
         return sub(left, right, ...)
      else
         return unm(left)
      end
   end

   -- helpers

   local function tail(arr)
      local out, len = {}, #arr
      for i=2, len do out[i - 1] = arr[i] end
      return out
   end

   local function flatten(arr)
      local buf, len = {}, #arr

      for i=1, len do
         local item = arr[i]

         if type(item) == 'table' and getmetatable(item) ~= atom then
            local arr2 = flatten(item)
            local len2 = #arr2
            for i=1, len2 do table.insert(buf, arr2[i]) end
         else
            table.insert(buf, item)
         end
      end

      return buf
   end

   -- implementation

   local xpr = {}
   local stm = {}

   local function form_xpr(head, ...)
      local name = atom.deref(head)

      local compiler = xpr[name]
      if compiler then return compiler(...) end

      print('WTF COMPILE ' .. name)
   end

   local function form_stm(head, ...)
   end

   local function form_lst(arr)
      local buf, len = {}, #arr

      for i=1, len do
         local item = arr[i]
         local buf2 = form_stm(unpack(item))

         table.insert(buf, buf2)
         table.insert(buf, '\n')
      end

      return buf
   end


   local function compile(ast)
      local buf = flatten(body(ast))
      local len = #buf
      for i=1, len do buf[i] = tostring(buf[i]) end
      return table.concat(buf, '')
   end

   return compile
