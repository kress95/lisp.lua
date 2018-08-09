
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
