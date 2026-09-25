local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

type PreferredInputType = Enum.PreferredInput
type InputKey = Enum.KeyCode | Enum.UserInputType | Enum.ModifierKey
type InputBindings = { [PreferredInputType]: { InputKey }? }
type InputContext = { string }

local Input = {} :: {
	fromData: (config: InputConfig) -> Input,
	changeState: (self: Input, isPressing: boolean) -> (),
	clearOverrides: (self: Input) -> (),
	withOverride: (self: Input, inputType: PreferredInputType, keys: { InputKey }) -> (),
	matches: (self: Input, preferredType: PreferredInputType, ctx: InputContext, input: InputObject) -> boolean,
}

export type InputConfig = {
	name: string,
	bindings: InputBindings,
	overrides: InputBindings?,
	ctx: { string }?,
}

export type Input = typeof(setmetatable(
	{} :: {
		name: string,
		pressing: boolean,
		pressed: Signal.Signal<boolean>,
		onOverride: Signal.Signal<>,
		bindings: InputBindings,
		overrides: InputBindings,
		ctx: { string },
	},
	{ __index = Input }
))

function Input.fromData(config: InputConfig)
	local self = setmetatable({}, { __index = Input }) :: Input

	self.name = config.name
	self.pressing = false

	self.pressed = Signal.new()
	self.onOverride = Signal.new()

	self.ctx = config.ctx or {}
	self.bindings = config.bindings
	self.overrides = config.overrides or {}

	return self
end

function Input:clearOverrides()
	self.overrides = {}
	self.onOverride:Fire()
end

function Input:withOverride(inputType: PreferredInputType, keys: { InputKey }?)
	self.overrides[inputType] = keys
	self.onOverride:Fire()
end

function Input:changeState(isPressing: boolean)
	if self.pressing == isPressing then
		return
	end

	self.pressing = isPressing
	self.pressed:Fire(isPressing)
end

function Input:matches(preferredType: PreferredInputType, ctx: InputContext, input: InputObject)
	local inputsPerType = self.bindings[preferredType]

	if not inputsPerType then
		return false
	end

	local boundInputs = self.overrides[preferredType] or self.bindings[preferredType]
	if not boundInputs then
		return false
	end

	for _, context in self.ctx do
		if not table.find(ctx, context) then
			return false
		end
	end

	if not next(boundInputs) then
		return false
	end

	for _, boundInput in boundInputs do
		local enumType = boundInput.EnumType

		if enumType == Enum.KeyCode then
			if input.KeyCode ~= boundInput :: Enum.KeyCode then
				return false
			end
		elseif enumType == Enum.UserInputType then
			if input.UserInputType ~= boundInput :: Enum.UserInputType then
				return false
			end
		elseif enumType == Enum.ModifierKey then
			if not input:IsModifierKeyDown(boundInput :: Enum.ModifierKey) then
				return false
			end
		end
	end

	return true
end

return Input
