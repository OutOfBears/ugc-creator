local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LinearValue = require(ReplicatedStorage.Shared.Modules.LinearValue)

local IS_CLIENT = RunService:IsClient()
local CUSTOM_IDENTIFIERS = {
	"UDim2",
	"UDim",
	"Vector2",
	"Vector3",
	"Color3",
	"ColorSequenceKeypoint",
	"NumberSequenceKeypoint",
	"NumberRange",
	"PhysicalProperties",
	"BrickColor",
	"CFrame",
}
local CUSTOM_CONSTRUCTORS = {
	["UDim2"] = UDim2.new,
	["UDim"] = UDim.new,
	["Vector2"] = Vector2.new,
	["Vector3"] = Vector3.new,
	["Color3"] = Color3.new,
	["ColorSequenceKeypoint"] = ColorSequenceKeypoint.new,
	["NumberSequenceKeypoint"] = NumberSequenceKeypoint.new,
	["NumberRange"] = NumberRange.new,
	["PhysicalProperties"] = PhysicalProperties.new,
	["BrickColor"] = BrickColor.new,
	["CFrame"] = CFrame.new,
}

type table = { [string | number]: any }

local instanceRefs = {}
local instanceGuids = {}

-- Constructing and deconstructing instances to string references

local function createRef(instance: Instance): string?
	if IS_CLIENT then
		return nil
	end

	if instanceRefs[instance] then
		return instanceRefs[instance]
	end

	local id = HttpService:GenerateGUID(false)
	instanceGuids[id] = instance
	instanceRefs[instance] = id

	instance:AddTag(id)
	instance.Destroying:Once(function()
		instanceGuids[id] = nil
		instanceRefs[instance] = nil
	end)

	return id
end

local function resolveRef(id: string, yield: boolean?)
	if instanceGuids[id] then
		return instanceGuids[id]
	end

	local instance = CollectionService:GetTagged(id)[1]
	if not instance and yield ~= false then
		instance = CollectionService:GetInstanceAddedSignal(id):Wait()
	end

	if instance then
		instanceGuids[id] = instance
		instanceRefs[instance] = id

		instance.Destroying:Once(function()
			instanceGuids[id] = nil
			instanceRefs[instance] = nil
		end)
	end

	return instance
end

-- Constructing and deconstructing custom tables
local function writeTable(tbl: table): table
	if getmetatable(tbl) or tbl.Destroy then
		return nil
	end

	local newTbl = {}

	for key, value in tbl do
		local valueType = typeof(value)

		if valueType == "table" then
			if getmetatable(value) or value.Destroy then
				continue
			end

			newTbl[key] = writeTable(value)
		elseif valueType == "Instance" then
			local ref = createRef(value)
			if ref then
				newTbl[key] = `\2{ref}`
			end
		elseif CUSTOM_CONSTRUCTORS[valueType] then
			local values = {}
			local identifier = table.find(CUSTOM_IDENTIFIERS, valueType)

			for _, value in LinearValue.fromValue(value)._value do
				table.insert(values, tostring(value))
			end

			assert(identifier, `Identifier not found for "{valueType}"`)
			newTbl[key] = "\3" .. string.char(identifier) .. table.concat(values, ",")
		else
			newTbl[key] = value
		end
	end

	return newTbl
end

local function readTable(tbl: table): table
	local newTbl = {}

	for key, value in tbl do
		local valueType = typeof(value)
		if valueType == "table" then
			newTbl[key] = readTable(value)
		elseif valueType == "string" then
			local identifier = string.byte(value, 1)
			local newValue = string.sub(value, 2)

			if identifier == 2 then
				newTbl[key] = resolveRef(newValue)
			elseif identifier == 3 then
				value = string.sub(newValue, 2)

				local newIdentifier = CUSTOM_IDENTIFIERS[string.byte(newValue, 1)]
				local constructor = CUSTOM_CONSTRUCTORS[newIdentifier]

				local values = {}
				for _, value in string.split(value, ",") do
					table.insert(values, tonumber(value))
				end

				newTbl[key] = constructor(unpack(values))
			else
				newTbl[key] = value
			end
		else
			newTbl[key] = value
		end
	end

	return newTbl
end

-- Turning any value into something that can be serialized into a string, and
-- Deserializing it back into the original value
-- BEWARE: This will ignore all custom objects, and objects with metatables

local function writeValue(value: any)
	if typeof(value) == "table" then
		-- Don't replicate tables with metatables or Destroy methods
		if getmetatable(value) or value.Destroy then
			return nil
		end

		return `\1{HttpService:JSONEncode(writeTable(value))}`
	else
		return value
	end
end

local function readValue(value: any)
	if typeof(value) == "InstanceHandle" then
		return value:Wait()
	end

	if typeof(value) ~= "string" then
		return value
	end

	local identifier = string.byte(value, 1)
	local newValue = string.sub(value, 2)

	if identifier == 1 then
		return readTable(HttpService:JSONDecode(newValue))
	end

	return value
end

return {
	writeValue = writeValue,
	readValue = readValue,
}
