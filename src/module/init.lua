-- @Author: VerdommeMan, see https://github.com/VerdommeMan/Spcall for more information 
-- @Version: 1.1.0

-- This module aims to solve the issue with the behaviour of the timeout error.
-- When the timeout error is generated, it will cascade the error into any related thread.
-- In other words, the timeout error indirectly propagates
-- This is due to to fact when the error is generated, the budget has been consumed
-- but it does not reset the budget after it has been catched, 
-- thus any code that tries to call, even code that attemps to yield, will raise that error too.
-- But I found out, that it wont cascade the error into threads that are suspended.
-- So what this module essentially does, is wrap the original thread in a suspended thread.
-- It doesn't look like much but it took me a long time to create this
-- It works in both SignalBehaviors (Deffered and Immediate) and supports continuations
-- It was a painful 20 hours in which I was slowly becoming insane but I did it :D

local Module = {}

-- Behaves like spawn, identical API, and benefits of task lib (continuations, stacktraces), resumes within the same frame

function Module.spawn(funcThread: (...any) -> () | thread, ...)
	task.defer(funcThread, ...) -- order 1, func gets called at order 3
	task.wait() -- order 2, suspends the current thread to prevent time out error from cascading into other threads
end

-- Pure black magic: abusing the mechanic that timeout doesnt error for indirectly calling metamethods (except __call)
-- (you can't yield in those though presumably why they are allowed to be indirectly called) 
-- It indirectly calls task.delay({}, thread, args), luckily the first arg defaults to zero instead
-- Schedules the thread to be resumed on the next step

local ThreadScheduler = setmetatable({}, {__newindex = task.delay})

-- Behaves like pcall and has identical API and almost identical behaviour
-- When yielding within it, it yields the thread it has been called in (just like pcall),
-- doesnt print anything in the console, one note though, since im unable to use table.pack
-- I wasnt able to preserve holes when returning from it, so you will have to return the amount of args incase that behaviour is wanted

function Module.pcall(func: (any) -> (), ...): (boolean, ...any)
	local curThread = coroutine.running()
	task.defer(function(...)
		ThreadScheduler[curThread] = {pcall(func, ...)} -- Absolute amazing piece of magic happening right here
	end, ...)
	return unpack(coroutine.yield())
end


-- Not similar to an existing function, exists bc coroutine.resume doesnt support continuations
-- When it doesn't error its behaviour is the same as pcall, when it does it returns success and a stacktrace containing the msg
-- Basically before this, I was using coroutine.resume to create create stacktraces from threads that have errored but since 
-- coroutine.resume doesnt catch errors when you yield in it (bc of continuations), it didnt work
-- Discovered that xpcall gives you one free call that doesn't trigger the timeout error, using it to generate a stacktrace
-- Luckily it also outputs the msg it was giving as param. 

function Module.tpcall(func: (any) -> (), ...) : (boolean, ...any)
	local curThread = coroutine.running()
	task.defer(function(...)
		ThreadScheduler[curThread] = {xpcall(func, debug.traceback, ...)}
	end, ...)
	return unpack(coroutine.yield())	
end

return Module

-- Incase you are interested, here are some findings I had during this project:
-- timeout doesn't error (when the budget is consumed) as long as you aren't calling anything
-- The timeout error can't propegate into threads that have been suspended, this is how I encapsulate the error
-- Some of my previous iterations before the ThreadScheduler were: polling a variable (very costly), 
-- Using a StringValue (could ve used any instance), listening to the Changed event, and change a property
-- But this was only effective for the Deffered SignalBehaviour since in that mode it calls the listeners after the budget has been reset