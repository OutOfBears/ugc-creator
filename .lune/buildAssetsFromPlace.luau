local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local remodel = require("./remodel")

local placeId = process.args[1]
assert(placeId, "Place ID is required as the first argument")

local game = remodel.readPlaceAsset(placeId)

local DELETE_FOLDERS = {
	"Packages",
	"Shared",
	"Client",
	"Server",
}

local function cleanDirectory(directory: Instance)
	for _, folder in DELETE_FOLDERS do
		local subFolder = directory:FindFirstChild(folder)
		if subFolder then
			subFolder:Destroy()
		end
	end
end

for _, obj in game:GetDescendants() do
	if obj:IsA("ModuleScript") or obj:IsA("LocalScript") or obj:IsA("Script") then
		obj:Destroy()
	end
end

for _, serviceName in { "ReplicatedStorage", "ServerStorage", "ServerScriptService" } do
	local service = game:GetService(serviceName)
	if service then
		cleanDirectory(service :: any)
	end
end

for _, subPlayerService in { "StarterCharacterScripts", "StarterPlayerScripts" } do
	local service = game:GetService("StarterPlayer"):FindFirstChild(subPlayerService)
	if service then
		cleanDirectory(service :: any)
	end
end

local assetsBuildFile = roblox.serializePlace(game)
fs.writeFile("Assets.rbxl", assetsBuildFile)

print("Assets.rbxl has been built successfully.")
