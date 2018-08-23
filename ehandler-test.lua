local eff = {}

local runtime = setmetatable({}, {__mode = "k"})

function eff.perform(eff, ...)
   return coroutine.yield(eff, ...)
end

local function handle_helper(handlers, co, alive, msg, ...)
   if not alive then
      error(msg, 0)
   end

   if coroutine.status(co) == "dead" then
      return msg, ...
   end

   local handler = handlers[msg]

   if handler then
      return handle_helper(handlers, co, coroutine.resume(co, handler(...)))
   else
      error("unhandled effect " .. msg)
   end
end

function eff.handle(handlers, fn, ...)
   local inside_handler = coroutine.running()

   if inside_handler then
      handlers = setmetatable(handlers, {__index = runtime[inside_handler]})
   end

   local co = coroutine.create(fn)
   runtime[co] = handlers
   return handle_helper(handlers, co, coroutine.resume(co, ...))
end

-- custom effect example

local function print_twice(str)
   print(str)
   print(str)
end

-- example function

local function puts_div(a, b)
   local c = a / b
   eff.perform("print", c)
   return c
end

-- prints once
print("=>", eff.handle({print = print}, puts_div, 20, 4)) -- returns 5

-- prints twice
print("=>", eff.handle({print = print_twice}, puts_div, 10, 2)) -- returns 5

-- quil test
do
   local function f()
      eff.perform("print", "hello, world")
   end

   local function g()
      f()
   end

   local function h()
      g()
   end

   local function main()
      eff.handle({}, h)
   end

   eff.handle({print=print}, main)
end

-- error
-- print("=>", eff.handle({}, puts_div, 10, 2))
