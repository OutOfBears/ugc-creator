local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClientEvents = require(ReplicatedStorage.Client.Modules.ClientEvents)
local InputContext = require(ReplicatedStorage.Client.Modules.InputContext)
local Inputs = require(ReplicatedStorage.Shared.Modules.Inputs)
local Types = require(ReplicatedStorage.Shared.Types)

local InputController = {} :: Types.Controller & {
	PreferredInputType: Enum.PreferredInput,
	getMatchingInputs: (input: InputObject) -> { Inputs.Input },
}

InputController.PreferredInputType = UserInputService.PreferredInput

function InputController.onInit()
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		InputController.PreferredInputType = UserInputService.PreferredInput

		for _, inputObject in Inputs do
			if inputObject.pressing then
				inputObject:changeState(false)
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		for _, matchedInput in InputController.getMatchingInputs(input) do
			matchedInput:changeState(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		for _, matchedInput in InputController.getMatchingInputs(input) do
			matchedInput:changeState(false)
		end
	end)

	ClientEvents.connect("add_input_context", function(context)
		assert(typeof(context) == "string", "Input context must be string")
		InputContext.add(context)
	end)
	ClientEvents.connect("remove_input_context", function(context)
		assert(typeof(context) == "string", "Input context must be string")
		InputContext.remove(context)
	end)
end

function InputController.getMatchingInputs(input: InputObject)
	local inputs = {}

	local preferredType = InputController.PreferredInputType
	local inputContext = InputContext.all()

	for _, inputObject in Inputs do
		if inputObject:matches(preferredType, inputContext, input) then
			table.insert(inputs, inputObject)
		end
	end

	return inputs
end

return InputController
