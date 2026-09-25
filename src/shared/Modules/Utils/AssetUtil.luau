local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InstanceUtil = require("./InstanceUtil")

--[=[
	@class AssetUtil

	Helpers for normalizing Roblox content/asset references and for reaching instances stored
	under `ReplicatedStorage.Assets`.
]=]

export type AssetId = string | number

--[=[
	@within AssetUtil
	@param id (string | number)? -- a numeric asset id, an existing content string, or nil
	@return string? -- a content string (`rbxassetid://<id>` for numbers), pass-through for strings, nil for nil

	Normalizes an image/sound reference into a content string so callers can accept either a
	bare asset id or a full content url interchangeably.
]=]
local function toContent(id: AssetId?): string?
	if id == nil then
		return nil
	end

	return if typeof(id) == "number" then `rbxassetid://{id}` else id :: string
end

--[=[
	@within AssetUtil
	@yields
	@param path string -- a slash-separated path below `ReplicatedStorage.Assets`, e.g. `"Blanks/RobotModel"`
	@return Instance -- the resolved instance

	Resolves an instance stored in the shared asset folder, yielding until it replicates. Errors
	if any segment never arrives. Every lookup into `ReplicatedStorage.Assets` goes through here
	so the folder's location is written down once.

	```lua
	local robot = AssetUtil.resolve("Blanks/RobotModel")
	```
]=]
local function resolve(path: string): Instance
	local assets = ReplicatedStorage:WaitForChild("Assets")

	return InstanceUtil.waitForChild(assets, path):expect()
end

--[=[
	@within AssetUtil
	@param path string -- a slash-separated path below `ReplicatedStorage.Assets`
	@return Instance? -- the instance, or nil if any segment is missing

	Non-yielding variant of [AssetUtil.resolve] for call sites that can handle a miss.
]=]
local function find(path: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end

	return InstanceUtil.findFirstChild(assets, path)
end

return {
	toContent = toContent,
	resolve = resolve,
	find = find,
}
