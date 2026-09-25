local RunService = game:GetService("RunService")

local IS_RUNNING = RunService:IsRunning()

local function now()
	if not IS_RUNNING then
		return os.clock()
	end

	return workspace:GetServerTimeNow()
end

local function nowMs()
	return math.floor(now() * 1000)
end

return {
	now = now,
	nowMs = nowMs,
}
