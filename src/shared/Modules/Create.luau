export type Props = {
	Children: { Instance }?,
	Attributes: { [string]: any }?,
	Tags: { string }?,
	[string | number]: any,
}

local Mutators = {
	Children = function(instance: Instance, children: { Instance })
		for _, child in children do
			child.Parent = instance
		end
	end,
	Attributes = function(instance: Instance, attributes: { [string]: any })
		for attrName, attrValue in attributes do
			instance:SetAttribute(attrName, attrValue)
		end
	end,
	Tags = function(instance: Instance, tags: { string })
		for _, tag in tags do
			instance:AddTag(tag)
		end
	end,
}

local function Create(className: string, properties: Props): Instance
	local obj = Instance.new(className)
	local parent = properties.Parent
	properties.Parent = nil

	for name, value in properties :: any do
		local mutator = Mutators[name]
		if mutator then
			mutator(obj, value)
		else
			(obj :: any)[name] = value
		end
	end

	obj.Parent = parent
	return obj
end

return Create
