type Handler<T> = (ctx: T, next: () -> ()) -> ()

type BaseMiddleware<T> = {
	new: () -> Middleware<T>,
	destroy: (self: Middleware<T>) -> (),
	use: (self: Middleware<T>, id: string, handler: Handler<T>) -> (),
	run: (self: Middleware<T>, id: string, ctx: T) -> T,
}

export type Middleware<T> = typeof(setmetatable(
	{} :: {
		_handlers: { [string]: { Handler<T> } },
	},
	{ __index = {} :: BaseMiddleware<T> }
))

local Middleware = {} :: BaseMiddleware<any>
Middleware.__index = Middleware

function Middleware.new<T>()
	local self = setmetatable({}, Middleware) :: Middleware<T>
	self._handlers = {}
	return self
end

function Middleware:destroy()
	self._handlers = {}
	table.clear(self)
end

function Middleware:use<T>(id: string, handler: Handler<T>)
	if not self._handlers[id] then
		self._handlers[id] = {}
	end
	table.insert(self._handlers[id], handler)
end

function Middleware:run<T>(id: string, ctx: T): T
	local handlers = self._handlers[id]
	if not handlers or #handlers == 0 then
		return ctx
	end

	local index = 0

	local function next()
		index += 1
		local handler = handlers[index]
		if handler then
			handler(ctx, next)
		end
	end

	next()
	return ctx
end

return Middleware
