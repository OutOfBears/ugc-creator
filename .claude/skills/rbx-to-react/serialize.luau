-- rbx-to-react: single-call instance serializer.
--
-- Paste this whole script into mcp__Roblox_Studio__execute_luau. Set ROOT_PATH to the
-- dotted path of the GuiObject you want (from search_game_tree). It returns ONE JSON tree
-- of the root and every descendant, with each instance's non-default serializable+writable
-- properties type-tagged so Roblox datatypes survive JSON. No per-node execute_luau calls.
-- It also records the authoring viewport and each node's AbsoluteSize/Position so the codegen
-- can rebuild the layout as device-relative scale rather than the captured device's offsets.
--
-- Property names come from ReflectionService:GetPropertiesOfClass, which reports each
-- property's Serialized flag, write security, and deprecation — so we ask the engine itself
-- which properties are serializable + writable rather than guessing a list.

local HttpService = game:GetService("HttpService")
local ReflectionService = game:GetService("ReflectionService")

-- EDIT this to the path search_game_tree gave you, e.g. "game.StarterGui.HUD.Root".
local ROOT_PATH = "game.StarterGui.YourScreen"

local SKIP_PROPS = { Parent = true, Name = true, Archivable = true }
local MAX_NODES = 4000

local defaults = {}
local nodeCount = 0
local classProps = {}

local function propsFor(className)
	local cached = classProps[className]
	if cached then
		return cached
	end

	local list = {}
	local ok, reflected = pcall(function()
		return ReflectionService:GetPropertiesOfClass(className)
	end)

	if ok then
		for _, prop in reflected do
			if not prop.Serialized or SKIP_PROPS[prop.Name] then
				continue
			end

			local writable = prop.Permits ~= nil and prop.Permits.Write ~= nil
			local deprecated = prop.Display ~= nil and prop.Display.DeprecationMessage ~= nil
			if writable and not deprecated then
				table.insert(list, prop.Name)
			end
		end
	end

	classProps[className] = list
	return list
end

local function tag(v)
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" then
		return v
	elseif t == "UDim2" then
		return { __t = "UDim2", x = { v.X.Scale, v.X.Offset }, y = { v.Y.Scale, v.Y.Offset } }
	elseif t == "UDim" then
		return { __t = "UDim", s = v.Scale, o = v.Offset }
	elseif t == "Vector2" then
		return { __t = "Vector2", x = v.X, y = v.Y }
	elseif t == "Vector3" then
		return { __t = "Vector3", x = v.X, y = v.Y, z = v.Z }
	elseif t == "Color3" then
		return { __t = "Color3", r = math.round(v.R * 255), g = math.round(v.G * 255), b = math.round(v.B * 255) }
	elseif t == "Rect" then
		return { __t = "Rect", min = { v.Min.X, v.Min.Y }, max = { v.Max.X, v.Max.Y } }
	elseif t == "NumberRange" then
		return { __t = "NumberRange", min = v.Min, max = v.Max }
	elseif t == "EnumItem" then
		return { __t = "Enum", e = tostring(v) }
	elseif t == "Font" then
		return { __t = "Font", family = v.Family, weight = tostring(v.Weight), style = tostring(v.Style) }
	elseif t == "ColorSequence" then
		local kp = {}
		for _, k in v.Keypoints do
			table.insert(kp, {
				t = k.Time,
				r = math.round(k.Value.R * 255),
				g = math.round(k.Value.G * 255),
				b = math.round(k.Value.B * 255),
			})
		end
		return { __t = "ColorSequence", keypoints = kp }
	elseif t == "NumberSequence" then
		local kp = {}
		for _, k in v.Keypoints do
			table.insert(kp, { t = k.Time, v = k.Value, env = k.Envelope })
		end
		return { __t = "NumberSequence", keypoints = kp }
	end

	return { __t = "raw", s = tostring(v) }
end

local function defaultFor(className)
	if defaults[className] == nil then
		local ok, inst = pcall(Instance.new, className)
		defaults[className] = if ok then inst else false
	end
	return defaults[className] or nil
end

local function isUiClass(inst)
	return inst:IsA("GuiObject") or inst:IsA("UIComponent")
end

local function serialize(inst)
	nodeCount += 1
	if nodeCount > MAX_NODES then
		error(`node cap {MAX_NODES} exceeded — narrow ROOT_PATH or raise MAX_NODES`)
	end

	local className = inst.ClassName
	local def = defaultFor(className)
	local props = {}

	for _, name in propsFor(className) do
		local ok, val = pcall(function()
			return (inst :: any)[name]
		end)
		if not ok or val == nil or typeof(val) == "Instance" then
			continue
		end

		local same = false
		if def then
			local okd, dval = pcall(function()
				return (def :: any)[name]
			end)
			if okd and dval == val then
				same = true
			end
		end

		if not same then
			props[name] = tag(val)
		end
	end

	local children = {}
	for _, child in inst:GetChildren() do
		if isUiClass(child) then
			table.insert(children, serialize(child))
		end
	end

	local node = { class = className, name = inst.Name, props = props, children = children }

	local okSize, absSize = pcall(function()
		return inst.AbsoluteSize
	end)
	if okSize and typeof(absSize) == "Vector2" then
		node.absSize = { absSize.X, absSize.Y }
	end

	local okPos, absPos = pcall(function()
		return inst.AbsolutePosition
	end)
	if okPos and typeof(absPos) == "Vector2" then
		node.absPos = { absPos.X, absPos.Y }
	end

	return node
end

local function resolve(path)
	local segs = {}
	for seg in string.gmatch(path, "[^%.]+") do
		table.insert(segs, seg)
	end
	assert(segs[1] == "game", "ROOT_PATH must start with 'game'")

	local node: any = game:GetService(segs[2])
	for i = 3, #segs do
		node = node:FindFirstChild(segs[i])
		assert(node, `could not resolve '{segs[i]}' in '{path}'`)
	end
	return node
end

local camera = workspace.CurrentCamera
local viewport = if camera then camera.ViewportSize else Vector2.zero

return HttpService:JSONEncode({
	viewport = { viewport.X, viewport.Y },
	tree = serialize(resolve(ROOT_PATH)),
})
