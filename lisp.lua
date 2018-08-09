setmetatable(_G, {
   __index = (function(_G, key)
      error((("variable ") .. (key) .. (" is not declared")), 2)
   end),
   __newindex = (function(_G, key)
      error((("declaring global ") .. (key) .. (" to ") .. (tostring(value))), 2)
   end),
})
local atom = {
}
