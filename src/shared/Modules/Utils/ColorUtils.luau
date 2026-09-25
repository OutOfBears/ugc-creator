local LIGHT_COLOR = Color3.fromRGB(255, 255, 255)
local DARK_COLOR = Color3.fromRGB(0, 0, 0)

local function lighten(color: Color3, amount: number)
	return color:Lerp(LIGHT_COLOR, amount)
end

local function darken(color: Color3, amount: number)
	return color:Lerp(DARK_COLOR, amount)
end

local function shift(color: Color3, h: number?, s: number?, v: number?)
	local h2, s2, v2 = color:ToHSV()

	if h then
		h2 = (h2 + h) % 1
	end
	if s then
		s2 = math.clamp(s2 + s, 0, 1)
	end
	if v then
		v2 = math.clamp(v2 + v, 0, 1)
	end

	return Color3.fromHSV(h2, s2, v2)
end

local function darkenSequence(sequence: ColorSequence, amount: number)
	local keypoints = {}

	for _, keypoint in ipairs(sequence.Keypoints) do
		table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, darken(keypoint.Value, amount)))
	end

	return ColorSequence.new(keypoints)
end

local function lightenSequence(sequence: ColorSequence, amount: number)
	local keypoints = {}

	for _, keypoint in ipairs(sequence.Keypoints) do
		table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, lighten(keypoint.Value, amount)))
	end

	return ColorSequence.new(keypoints)
end

local function shiftSequence(sequence: ColorSequence, h: number?, s: number?, v: number?)
	local keypoints = {}

	for _, keypoint in ipairs(sequence.Keypoints) do
		table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, shift(keypoint.Value, h, s, v)))
	end

	return ColorSequence.new(keypoints)
end

return {
	lighten = lighten,
	darken = darken,
	shift = shift,

	lightenSequence = lightenSequence,
	darkenSequence = darkenSequence,
	shiftSequence = shiftSequence,
}
