local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useEffect = React.useEffect
local useState = React.useState

type Ref<T> = { current: T? }

local function getVisibilityProperty(instance: Instance): string?
	if instance:IsA("GuiObject") then
		return "Visible"
	elseif instance:IsA("LayerCollector") or instance:IsA("BillboardGui") then
		return "Enabled"
	end
	return nil
end

local function isLocallyVisible(instance: Instance): boolean
	local prop = getVisibilityProperty(instance)
	if not prop then
		return true
	end
	return (instance :: any)[prop]
end

local function computeVisible(instance: Instance?): boolean
	if not instance then
		return false
	end

	local current: Instance? = instance
	while current and current ~= game do
		if not isLocallyVisible(current) then
			return false
		end
		current = current.Parent
	end
	return true
end

--[=[
	@function useVisible
	@within Hooks

	Returns whether the instance referenced by `ref` is visible, taking ancestry
	into account. The result is `false` if the ref is empty, the instance or any
	ancestor `GuiObject` has `Visible = false`, or any ancestor `LayerCollector`
	/ `BillboardGui` has `Enabled = false`.

	@param ref Ref<Instance> -- A React ref pointing to the instance to observe.

	@return boolean -- A boolean state value that updates when visibility changes anywhere
		in the ancestor chain or when the instance is reparented.
]=]
local function useVisible(ref: Ref<Instance>): boolean
	local visible, setVisible = useState(function()
		return computeVisible(ref.current)
	end)

	useEffect(function()
		local instance = ref.current
		if not instance then
			setVisible(false)
			return
		end

		local connections: { RBXScriptConnection } = {}
		local rebuild: () -> ()

		local function update()
			setVisible(computeVisible(instance))
		end

		rebuild = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)

			local current: Instance? = instance
			while current and current ~= game do
				local prop = getVisibilityProperty(current)
				if prop then
					table.insert(connections, current:GetPropertyChangedSignal(prop):Connect(update))
				end
				table.insert(
					connections,
					current.AncestryChanged:Connect(function()
						rebuild()
						update()
					end)
				)
				current = current.Parent
			end

			update()
		end

		rebuild()

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { ref } :: { any })

	return visible
end

return useVisible
