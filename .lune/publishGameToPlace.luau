local fs = require("@lune/fs")
local net = require("@lune/net")

local process = require("@lune/process")
local serde = require("@lune/serde")

local PLACE_FILE = "Game.rbxl"
local apiKey = process.env.RBX_CLOUD_TOKEN
assert(apiKey and #apiKey > 0, "RBX_CLOUD_TOKEN environment variable must be set")

local placeId = process.args[1]
assert(placeId, "Usage: lune run publishGameToPlace <placeId>")
assert(fs.isFile(PLACE_FILE), `Place file "{PLACE_FILE}" not found`)

local function resolveUniverseId(place: string): string
	local resp = net.request({
		url = `https://apis.roblox.com/universes/v1/places/{place}/universe`,
		method = "GET",
	})
	assert(resp.ok, `Could not resolve universe for place {place}: {resp.statusCode} {resp.statusMessage}`)

	local body = serde.decode("json", resp.body)
	return body.universeId
end

local function publishVersion(universe: string, place: string, fileContents: buffer | string)
	local resp = net.request({
		url = `https://apis.roblox.com/universes/v1/{universe}/places/{place}/versions?versionType=Published`,
		method = "POST",
		body = fileContents,
		headers = {
			["Content-Type"] = "application/octet-stream",
			["x-api-key"] = apiKey,
			Accept = "application/json",
		},
	})
	if not resp.ok then
		error(`Publish failed for place {place}: {resp.statusCode} {resp.statusMessage}\n{resp.body}`)
	end
end

local universeId = resolveUniverseId(placeId)
print(`Resolved universe: {universeId}`)

publishVersion(universeId, placeId, fs.readFile(PLACE_FILE))
print(`Published {PLACE_FILE} to place {placeId}`)
