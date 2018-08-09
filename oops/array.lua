local array = {__index = {}}

function array.create(arr)
   arr[0] = #arr
   return setmetatable(arr, array)
end

function array:__len()
   return self[0]
end

local function next(arr, index)
   local length = arr[0]

   while index < length do
      index = index + 1

      local item = arr[index]

      if item ~= nil then
         return index, arr[index]
      end
   end
end

function array:__ipairs()
   return next, self, 0
end

function array:__tostring()
   local arr = {}

   for k,v in ipairs(self) do
      arr[k] = tostring(v)
   end

   return '(' .. table.concat(arr, ' ') .. ')'
end

function array.__index:push(item)
   local length = self[0] + 1

   self[length] = item
   self[0] = length

   return length
end

function array.__index:pop()
   if self[0] > 0 then
      local length = self[0]
      local popped = self[length]

      self[length] = nil
      self[0] = length - 1

      return popped
   end
end

function array.__index:last()
   if self[0] > 0 then
      return self[self[0]]
   end
end

function array.__index:to_table()
   self[0] = nil
   setmetatable(self, nil)
   return self
end

return array
