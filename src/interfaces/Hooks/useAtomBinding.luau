local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local React = require(ReplicatedStorage.Packages.React)

local useEffect = React.useEffect
local useBinding = React.useBinding
local useCallback = React.useCallback
local useRef = React.useRef

local function getValue<T>(atom: Charm.Atom<T>, default: T?): T
	return useCallback(function()
		local value = atom()
		return if value ~= nil then value else default
	end, { atom, default })
end

--[=[
	@function useAtomBinding
	@within Hooks

	Like `useAtom`, but returns a React binding that updates without re-rendering the component.

	@param atom Atom<T> -- the atom to read and subscribe to
	@param default T? -- value the binding holds while the atom is nil
	@param dependencies { any }? -- effect dependencies; defaults to the internal getter
	@return React.Binding<T> -- a binding tracking the atom's value
]=]
local function useAtomBinding<T>(atom: Charm.Atom<T>, default: T?, dependencies: { any }?): T
	local getter = getValue(atom, default)

	local first = useRef(true)
	local state, setState = useBinding(if first.current then getter() else default)

	first.current = false

	useEffect(function()
		setState(getter())
		return Charm.subscribe(atom, function()
			setState(getter())
		end)
	end, dependencies or { getter })

	return state
end

return useAtomBinding
