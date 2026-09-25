-- TODO(post-MVP): replication uses a single `playerData` attribute, which is
-- JSON-encoded into one string. Roblox attribute strings cap at ~4KB, so the
-- whole profile (including `inventory`) must fit. With duplicates allowed this
-- caps inventory at roughly 30-50 items before SetAttribute starts failing.
-- Planned fix: move `inventory` off attributes entirely and replicate it as a
-- table over a dedicated RemoteEvent — server is authoritative, fires an
-- initial snapshot to a player on join and per-mutation diffs (add / remove /
-- update by item id) to all clients afterward. Trading is a server-side table
-- mutation that fans out the same diff to the involved clients (and to others
-- when the trade should be public). Keep the small bounded fields (level, class,
-- loadOut, classLevels) on per-field attributes via AttributeReplicator; `cash`
-- is already done, below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AttributeReplicator = require(ReplicatedStorage.Shared.Modules.AttributeReplicator)
local Behavior = require(ReplicatedStorage.Shared.Modules.Behavior)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local PlayerTemplate = require(ServerScriptService.Server.Data.PlayerTemplate)
local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local Promise = require(ReplicatedStorage.Shared.Modules.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)

local playerStore = ProfileStore.New("PlayerData", PlayerTemplate)

type PlayerTemplate = typeof(PlayerTemplate)
type Replicator = AttributeReplicator.AttributeReplicator<Instance, any>
type BehaviorBase<I> = Behavior.BehaviorBase<I>

--[=[
	@class ServerPlayerProfile
	@server

	Owns a player's ProfileStore session: loads and saves persistent data,
	replicates it, and exposes path-keyed get/set with a changed signal.
]=]

--[=[
	@interface ServerPlayerProfile
	@within ServerPlayerProfile
	.ready boolean -- true once the session has loaded
	.replicator Replicator -- attribute replicator carrying the player's data
	.session ProfileStore.Profile<PlayerTemplate>? -- active ProfileStore session, nil until loaded
	.changed Signal.Signal<(string) -> ()> -- fired with the changed key on a data write
	.loaded Signal.Signal<() -> ()> -- fired once the session has loaded
]=]
export type Profile = BehaviorBase<Player> & {
	-- vars
	replicator: Replicator,
	session: ProfileStore.Profile<PlayerTemplate>?,
	ready: boolean,

	changed: Signal.Signal<(string) -> ()>,
	loaded: Signal.Signal<() -> ()>,

	-- methods
	init: (self: Profile) -> (),
	destroy: (self: Profile) -> (),
	saveAsync: (self: Profile) -> (),
	loadAsync: (self: Profile) -> Promise.AnyPromise,
	set: <T>(self: Profile, key: string, value: T?) -> (),
	get: <T>(self: Profile, key: string) -> T?,
}

local function getProfileValue<T>(profile: Profile, key: string): T?
	local value = profile

	for _, segment in string.split(key, "/") do
		value = value[segment]
		if not value then
			break
		end
	end

	return value
end

local function setProfileValue<T>(profile: Profile, key: string, value: T?)
	local setter = profile
	local segments = string.split(key, "/")
	local leaf = table.remove(segments)

	if leaf == nil then
		return false
	end

	for _, segment in segments do
		setter = setter[segment]
		if setter == nil then
			return false
		end
	end

	if setter[leaf] == value and typeof(value) ~= "table" then
		return false
	end

	setter[leaf] = value
	return true
end

local function Profile(instance: Player, replicator: Replicator)
	local destroyed = false
	local userId = instance.UserId

	local maid = Maid.new()
	local profile = {} :: Profile
	local session = nil :: ProfileStore.Profile<PlayerTemplate>?

	profile.ready = false
	profile.session = nil
	profile.instance = instance
	profile.replicator = replicator
	profile.loaded = Signal.new()
	profile.changed = Signal.new()

	maid:giveTask(profile.loaded)
	maid:giveTask(profile.changed)

	maid:giveTask(profile.changed:Connect(function(_: string)
		if session then
			replicator:Set("playerData", session.Data)
		end
	end))

	function profile:init()
		maid:giveTask(function()
			if session then
				profile.ready = false
				session:EndSession()
				session = nil
				profile.session = nil
			end
		end)

		self:loadAsync():expect()
	end

	function profile:destroy()
		destroyed = true
		maid:doCleaning()
	end

	--[=[
		@within ServerPlayerProfile

		Persists the active session's data, if a session is loaded.
	]=]
	function profile:saveAsync()
		if session then
			session:Save()
		end
	end

	--[=[
		@within ServerPlayerProfile
		@return Promise.AnyPromise -- resolves with the loaded session

		Starts (or returns the existing) ProfileStore session and replicates its
		initial data.
	]=]
	function profile:loadAsync()
		return Promise.new(function(resolve, reject, onCancel)
			if session then
				resolve(session)
				return
			end

			local cancelled = false
			onCancel(function()
				cancelled = true
			end)

			profile.ready = false

			local newSession = playerStore:StartSessionAsync(`{userId}`, {
				Cancel = function()
					return instance.Parent ~= Players
				end,
			})

			if instance.Parent ~= Players or destroyed then
				if newSession then
					newSession:EndSession()
				end

				reject("player left during loading")
				return
			end

			if newSession ~= nil then
				if cancelled then
					session = nil

					newSession:EndSession()
					reject("loading cancelled")

					return
				end

				newSession:AddUserId(userId)
				newSession:Reconcile()

				newSession.OnSessionEnd:Connect(function()
					if session == newSession then
						session = nil
						profile.session = nil
						profile.ready = false
					end
				end)

				session = newSession
				profile.session = newSession
				replicator:Set("playerData", session.Data)

				profile.ready = true
				self.loaded:Fire()
				resolve(newSession)
			else
				reject("failed to load profile")
			end
		end)
	end

	--[=[
		@within ServerPlayerProfile
		@param key string -- slash-delimited path into the session data
		@return T? -- the value at the path, or nil if unset/no session
	]=]
	function profile:get<T>(key: string): T?
		if not session then
			return
		end

		return getProfileValue(session.Data, key)
	end

	--[=[
		@within ServerPlayerProfile
		@param key string -- slash-delimited path into the session data
		@param value T? -- the value to write at the path

		Writes the value and fires `changed` when the data actually changed.
	]=]
	function profile:set<T>(key: string, value: T?)
		if not session then
			return
		end

		local changed = setProfileValue(session.Data, key, value)
		if changed then
			self.changed:Fire(key)
		end
	end

	profile:init()
	return profile
end

return Behavior("Player", Profile, {
	instanceType = "Player",
	ancestors = { Players },
	-- change this later
	replicated = true,
})
