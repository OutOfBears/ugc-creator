local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local IS_RUNNING = RunService:IsRunning()

if not IS_RUNNING then
	return require(script.Dummy)
end

return {
	client = function()
		assert(not IS_SERVER, "Network 'client' module cannot be required on the server")
		return require(script.Client)
	end,
	server = function()
		assert(IS_SERVER, "Network 'server' module cannot be required on the client")
		return require(script.Server)
	end,
}
