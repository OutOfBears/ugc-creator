-- Camera Shaker Config
--
-- Tunables and distance-falloff curves for the CameraShaker. Kept dependency-free
-- so the whole CameraShaker folder can be copy-pasted between projects untouched.

export type FalloffId = "Constant" | "Linear" | "Smooth" | "Exponential" | "InverseExponential" | "InverseSquare"

local EXP_STEEPNESS = 4
local INVERSE_SQUARE_K = 8

local EXP_MIN = math.exp(-EXP_STEEPNESS)
local EXP_DENOM = 1 - EXP_MIN
local ISQ_MIN = 1 / (1 + INVERSE_SQUARE_K)
local ISQ_DENOM = 1 - ISQ_MIN

local function smootherstep(t: number): number
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function exponential(t: number): number
	return (math.exp(-EXP_STEEPNESS * t) - EXP_MIN) / EXP_DENOM
end

-- Each curve maps normalized distance t (0 at the source, 1 at the radius edge)
-- to an attenuation multiplier that is 1 at t=0 and 0 at t=1.
local falloffs: { [FalloffId]: (t: number) -> number } = {
	Constant = function(_t: number): number
		return 1
	end,

	Linear = function(t: number): number
		return 1 - t
	end,

	Smooth = function(t: number): number
		return 1 - smootherstep(t)
	end,

	Exponential = exponential,

	InverseExponential = function(t: number): number
		return 1 - exponential(1 - t)
	end,

	InverseSquare = function(t: number): number
		return (1 / (1 + INVERSE_SQUARE_K * t * t) - ISQ_MIN) / ISQ_DENOM
	end,
}

table.freeze(falloffs)

local Config = {
	DEFAULT_RADIUS = 60,
	DEFAULT_FALLOFF = "Linear" :: FalloffId,
	defaultPosInfluence = Vector3.new(0.15, 0.15, 0.15),
	defaultRotInfluence = Vector3.new(1, 1, 1),
	falloffs = falloffs,
}

return table.freeze(Config)
