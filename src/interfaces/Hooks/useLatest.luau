local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useMemo = React.useMemo
local useRef = React.useRef

--[=[
	@function useLatest
	@within Hooks

	Returns a ref that always holds the latest `value`, letting stable callbacks read the current value without re-subscribing. An optional `predicate` gates whether the ref updates.

	@param value T -- the value to keep current in the ref
	@param predicate ((current: T, next: T) -> boolean)? -- when provided, the ref only updates if it returns true
	@return { current: T } -- a ref holding the most recent value
]=]
local function useLatest<T>(value: T, predicate: ((T, T) -> boolean)?)
	local ref = useRef(value)

	useMemo(function()
		if not predicate or predicate(ref.current, value) then
			ref.current = value
		end
	end, { value })

	return ref
end

return useLatest
