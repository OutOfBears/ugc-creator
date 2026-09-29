local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local React = require(ReplicatedStorage.Packages.React)

local useEffect = React.useEffect
local useState = React.useState
local useCallback = React.useCallback

local function getValue<T>(atom: Charm.Atom<T>, default: T?): T
	return useCallback(function()
		local value = atom()
		return if value ~= nil then value else default
	end, { atom, default })
end

--[=[
	@function useAtom
	@within Hooks

	Subscribes to a Charm atom and re-renders the component when its value changes.

	@param atom Atom<T> -- the atom to read and subscribe to
	@param default T? -- value returned while the atom holds nil
	@param dependencies { any }? -- effect dependencies; defaults to the internal getter
	@return T -- the atom's current value, or `default` when nil
]=]
local function useAtom<T>(atom: Charm.Atom<T>, default: T?, dependencies: { any }?): T
	local getter = getValue(atom, default)
	local state, setState = useState(getter)

	useEffect(function()
		setState(getter())
		return Charm.subscribe(atom, function()
			setState(getter())
		end)
	end, dependencies or { getter })

	return state
end

return useAtom
