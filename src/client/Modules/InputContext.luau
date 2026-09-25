--[=[
	@class InputContext
	@client

	Owns the set of active input contexts that gate which bindings fire (see
	InputObject:matches). Membership is idempotent, so independent callers — the class
	hotbar, server-pushed contexts — can toggle the same context without duplicating or
	clobbering each other.
]=]
local InputContext = {}

local active = {} :: { string }

--[=[
	@within InputContext
	@return { string } -- the active contexts, as read by InputObject:matches
]=]
function InputContext.all(): { string }
	return active
end

--[=[
	@within InputContext
	@param name string -- context to activate; a no-op if already active
]=]
function InputContext.add(name: string)
	if not table.find(active, name) then
		table.insert(active, name)
	end
end

--[=[
	@within InputContext
	@param name string -- context to deactivate; a no-op if not active
]=]
function InputContext.remove(name: string)
	local index = table.find(active, name)
	if index then
		table.remove(active, index)
	end
end

--[=[
	@within InputContext
	@param name string -- context to toggle
	@param isActive boolean -- whether the context should be active
]=]
function InputContext.set(name: string, isActive: boolean)
	if isActive then
		InputContext.add(name)
	else
		InputContext.remove(name)
	end
end

return InputContext
