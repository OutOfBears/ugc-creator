local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useCallback = React.useCallback
local useEffect = React.useEffect

--[=[
	@function useEvent
	@within Hooks

	Connects `fn` to `event` for the component's lifetime, reconnecting when `event` or the memoized handler changes. The handler is memoized on `deps`.

	@param event RBXScriptSignal<T...> -- the signal to connect to
	@param fn (T...) -> () -- the handler to run on each fire
	@param deps { any } -- dependency list controlling when the handler is rebuilt
]=]
local function useEvent<T...>(event: RBXScriptSignal<T...>, fn: (T...) -> (), deps: { any })
	local memoizedFn = useCallback(fn, deps)

	useEffect(function()
		local connection = event:Connect(memoizedFn)
		return function()
			connection:Disconnect()
		end
	end, { event :: any, memoizedFn })
end

return useEvent
