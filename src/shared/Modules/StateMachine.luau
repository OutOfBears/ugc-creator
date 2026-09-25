local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Logger = require("./Logger")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local PooledConnection = require(script.Parent.PooledConnection)
local Signal = require(ReplicatedStorage.Packages.Signal)

local logger = Logger.new()

export type StateTransition<T> = {
	to: T,
	guard: ((self: StateMachine<T>, from: State<T>, to: State<T>) -> boolean)?,
	action: ((self: StateMachine<T>, from: State<T>, to: State<T>) -> ())?,
}
export type StateTransitions<T> = { [string]: StateTransition<T> }

export type State<T> = {
	name: T,
	parent: T?,
	transitions: StateTransitions<T>?,
	onEnter: ((self: StateMachine<T>, from: State<T>?, values: any?) -> ())?,
	onLeave: ((self: StateMachine<T>, to: State<T>?, values: any?) -> ())?,
	onUpdate: ((self: StateMachine<T>, dt: number) -> ())?,
}

type BaseStateMachine<T> = {
	transitions: (states: { T }) -> { [T]: StateTransition<T> },
	allTransitions: (self: StateMachine<T>) -> { [string]: StateTransition<T> },
	new: (states: { [T]: State<T> }?) -> StateMachine<T>,
	Destroy: (self: StateMachine<T>) -> (),
	addState: (self: StateMachine<T>, state: State<T>) -> (),
	setInitial: (self: StateMachine<T>, state: T, values: any?) -> (),
	start: (self: StateMachine<T>) -> (),
	stop: (self: StateMachine<T>) -> (),
	changeState: (self: StateMachine<T>, event: string, values: any?) -> (),
	_climb: (self: StateMachine<T>, state: State<T>?, callback: (state: State<T>) -> ()) -> (),
}

export type StateMachine<T> = typeof(setmetatable(
	{} :: {
		maid: Maid.Maid,
		changed: Signal.Signal<State<T>?, State<T>>,
		current: State<T>?,
		value: any?,
		states: { [T]: State<T> },
		values: { [T]: any },
		running: boolean,
		_updating: boolean,
		_thread: thread?,
		_connection: RBXScriptConnection?,
	},
	{ __index = {} :: BaseStateMachine<T> }
))

local StateMachine = {} :: BaseStateMachine<any>

function StateMachine.transitions<T>(states: { T }, transitions: StateTransitions<T>?): StateTransitions<T>
	local result = {} :: StateTransitions<T>

	for _, state in states do
		result[state :: any] = {
			to = state,
		}
	end

	if transitions then
		for name, value in transitions do
			result[name] = value
		end
	end

	return result
end

function StateMachine:allTransitions<T>(): StateTransitions<T>
	local result = {} :: StateTransitions<T>

	for _, state in self.states do
		result[state.name] = { to = state.name }
	end

	return result
end

function StateMachine.new<T>(states: { [T]: State<T> }?)
	local self = setmetatable({}, { __index = StateMachine }) :: StateMachine<T>

	self.maid = Maid.new()
	self.changed = Signal.new()

	self.states = states or {}
	self.values = {}

	self.current = nil
	self.running = false

	self.maid:giveTask(function()
		self.running = false
		self._thread = nil

		if self._connection then
			self._connection:Disconnect()
			self._connection = nil
		end
	end)

	return self
end

function StateMachine:Destroy<T>()
	self.changed:Destroy()
	self.maid:doCleaning()
end

function StateMachine:_climb<T>(state: State<T>?, callback)
	while state do
		callback(state)
		state = state.parent and self.states[state.parent] or nil
	end
end

function StateMachine:addState<T>(state: State<T>)
	self.states[state.name] = state
end

function StateMachine:setInitial<T>(name: T, values: any?)
	self.current = self.states[name]
	assert(self.current, `Invalid initial state: {name :: any}`)
	self.values[name] = values
end

function StateMachine:changeState<T>(event: string, values: any?)
	if not self.current then
		return
	end

	if self.current.name == event then
		return
	end

	local from = self.current
	local targetTransition

	self:_climb(from, function(state)
		local t = state.transitions and state.transitions[event]
		if t then
			targetTransition = t
		end
	end)

	local to = if targetTransition then self.states[targetTransition.to] else self.states[event]
	assert(to, "Target state missing: " .. if targetTransition then targetTransition.to else event)

	if targetTransition and targetTransition.guard and not targetTransition.guard(self, from, to) then
		return
	end

	self:_climb(from, function(state)
		if state.onLeave then
			task.spawn(state.onLeave, self, to, self.value)
		end
	end)

	if targetTransition and targetTransition.action then
		targetTransition.action(self, from, to)
	end

	self.values[to.name] = values
	self.value = values
	self.current = to

	local entryChain = {}
	local p = to :: State<T>?
	while p do
		table.insert(entryChain, 1, p)
		p = p.parent and self.states[p.parent] or nil
	end

	for _, chain in entryChain do
		if chain.onEnter then
			task.spawn(chain.onEnter, self, from, self.value)
		end
	end

	self.changed:Fire(from, to)
end

function StateMachine:start<T>()
	if self.running then
		return
	end

	self.running = true
	self._updating = false

	self._thread = coroutine.create(function()
		while true do
			local dt = coroutine.yield()

			if self.current then
				local ok, err = xpcall(self._climb, debug.traceback, self, self.current, function(state)
					if state.onUpdate then
						state.onUpdate(self, dt)
					end
				end)

				if not ok then
					logger:error(`onUpdate errored:\n{err}`)
				end
			end

			self._updating = false
		end
	end)

	coroutine.resume(self._thread)

	self._connection = PooledConnection(RunService.PreSimulation):Connect(function(dt)
		local thread = self._thread
		if not thread or not self.current or self._updating then
			return
		end

		self._updating = true
		coroutine.resume(thread, dt)
	end)
end

function StateMachine:stop<T>()
	self.running = false
	self._thread = nil

	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return StateMachine
