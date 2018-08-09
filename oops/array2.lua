local array_mt = {index={}}

local function array(tbl)
   tbl[0] = #tbl
   return setmetatable(tbl, array_mt)
end

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

function array_mt:__tostring()
   local acc = {}
   local len = self[0]

   for i=1, len do
      acc[i] = tostring(self[i])
   end

   return '(' .. table.concat(acc, ' ') .. ')'
end

function array_mt:__len()
   return self[0]
end

function array_mt:__ipairs()
   return next, self, 0
end

function array_mt.index:head()
   return self[1]
end

function array_mt.index:tail()
   local out = {}
   local len = self[0]

   for i=2, len do
      out[i - 1] = self[i]
   end

   return array(out)
end

function array_mt.index:push(item)
   local len = self[0] + 1

   self[len] = item
   self[0] = len
end

function array_mt.index:pop(item)
   if self[0] > 0 then
      local len = self[0]
      local pop = self[len]

      self[len] = nil
      self[0] = len - 1

      return pop
   end
end

return setmetatable(array_mt, {
   __index = { new = array },
   __call = function (self, ...) return array(...) end,
})
