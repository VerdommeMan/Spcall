# Spcall

## In short: 

This module offers replacements that prevent the propagation of the timeout error.

## Long:

This module aims to solve an issue with the behaviour of the timeout error.
When the timeout error is generated, it will cascade the error into any related thread.
In other words, the timeout error indirectly propagates.
This is due to to fact when the error is generated, the budget has been consumed but it does not reset the budget after it has been catched.
Thus any code that tries to call, even code that attemps to yield, will raise that error too.
But I found out, that it won't cascade the error into threads that are suspended.
So what this module essestially does, is wrap the original thread in a suspended thread.
So this module makes sure the timeout error will behave like any other error.


## Example of the issue with the timeout error
```lua
task.spawn(function() 
	coroutine.resume(coroutine.create(function() 
		task.spawn(function()
			pcall(function() 
				while true do -- raise the timeout error
					
				end
			end)
			print("This will raise another timeout error")
			print("Never prints due to that this thread has errored")
		end)
	end))
	print("Even this will error")
end)
print("As you can see it indirectly propegates the timeout error")
```
![output](https://i.imgur.com/xfnHdVa.png)

## TOC
- [In short:](#in-short)
- [Long:](#long)
- [Example of the issue with the timeout error](#example-of-the-issue-with-the-timeout-error)
- [TOC](#toc)
- [Use case](#use-case)
	- [A more concrete use case](#a-more-concrete-use-case)
		- [Without it:](#without-it)
		- [Now with it:](#now-with-it)
- [Disclaimer](#disclaimer)
- [Download](#download)
- [Code examples](#code-examples)
- [API](#api)
	- [Functions](#functions)
		- [`void` module.spawn(funcThread: func | thread, ...: any)](#void-modulespawnfuncthread-func--thread--any)
		- [`(bool, str | any, ...any)` module.pcall(func: func, ...: any)](#bool-str--any-any-modulepcallfunc-func--any)
- [Other](#other)

## Use case

In most cases, the default behaviour of timeout is not that bad, it fails fast. Forcing you to the fix the issue. But when handling 3rd party code, e.g. code you have no control over. And you want to properly handle said code, including the timeout error. This would not be possible without this module.

An even more niche use case, is when the during the cascading of the error it generates that many errors and stacktraces that the root stacktrace (the code that actually caused it) is no longer accessible.

[An example of this happening to me (link to gif)](https://imgur.com/a/VEd4Pkd)

In the gif you can see it only shows a portion of the 2000 errors that it had raised.

### A more concrete use case

#### Without it:

For one of my other modules people write benchmarks -> one errors with the timeout error -> it cascades through out my whole module -> whole module unresponsive -> not debuggable in the slighest, because you get 2k errors (see gif above) -> module completely unreponsive -> unable to do the other benchmarks/profiling -> can't even close/mimize the gui.

#### Now with it:
People write benchmarks -> one errors with the timeout error -> catched -> doesnt propegate -> handle error -> e.g. visual status informing benchmark X, errored, prints the error and the stack trace (1 error not 2k errors) -> other benchmarks/profiling keep running -> add hints how to fix the error -> benchmarker keeps being completely useable -> also doesn't take 10 minutes for studio to become responsive again

## Disclaimer

This is not a **general** replacement for `task.spawn` and `pcall`. It's only for this use case.
You can but there is no point.

## Download
- [from the release page](https://github.com/VerdommeMan/Spcall/releases)
- [link to roblox asset page](https://www.roblox.com/library/7271228051/Spcall-prevent-propagation-of-the-timeout-error)
- or you can build it from [src](/src) using rojo
  
## Code examples
It has identical API to the roblox counterparts, so you can use them as drop in replacements.

Fixed version of the example issue:
```lua
local module = require(...)

task.spawn(function() 
	coroutine.resume(coroutine.create(function() 
		task.spawn(function()
			mod.pcall(function() 
				while true do -- raise the timeout error
					
				end
			end)
			print("This will raise another timeout error")
			print("Never prints due to that this thread has errored")
		end)
	end))
	print("Even this will error")
end)
print("As you can see it indirectly propegates the timeout error")
```
And now it will print all those prints
![image of output](https://i.imgur.com/qWDkVdi.png)

And here is the other replacement:
```lua
local module = require(...)

module.spawn(function() 
	while true do end
end)

print("This will print")
```

and the output, as you can see it prints the stacktrace but it doesnt propegate the error
![output code above](https://i.imgur.com/lEMTfvO.png)


## API
The module offers two replacements: one for pcall and one for task.spawn

The have an identical API

### Functions

#### `void` module.spawn(funcThread: func | thread, ...: any)

Behaves like `task.spawn` and benefits of task lib (continuations, stacktraces), resumes within the same frame. But prevents the propagation of the timeout error.

#### `(bool, str | any, ...any)` module.pcall(func: func, ...: any)

Behaves almost exactly like `pcall`, but doesn't propagate the timeout error.

Few caveats though:
- Since I was unable to use `table.pack`, I wasn't able to preserve holes when returning from pcall, so when that behaviour is wanted I suggest you pack the tuple before you return it.
- As you can see from the code example for `module.pcall`, the order of the print statements isn't exactly the same as it would ve been with pcall. This is due to fact that I can't resume the the thread immediately because the budget has't been reset yet. Instead it resumes it on the next step.

## Other
- It works in Deffered and supports continuations.
- If you are interested in how it works, [read these comments](src/../init.lua)
  