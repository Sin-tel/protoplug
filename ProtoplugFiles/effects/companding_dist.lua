-- compression before softclipping, then applies the inverse gain after to maintain dynamics

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local b = 1
local c = 1

local expFactor = -1000.0 / 44100

local balance = 0.0

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local attack = timeConstant(20)
local release = timeConstant(80)

stereoFx.init()
function stereoFx.Channel:init()
	self.peak = 0
end

function softclip(x)
	local s = math.min(math.max(x, -3.0), 3.0)
	return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]
		local peak = inp * inp

		if peak < self.peak then
			self.peak = self.peak - (self.peak - peak) * attack
		else
			self.peak = self.peak - (self.peak - peak) * release
		end

		local p = math.sqrt(self.peak)

		local g = (1 - balance) + balance * b * c / (p + b)

		local s = inp * g

		s = softclip(s) / g

		samples[i] = s
	end
end

params = plugin.manageParams({
	{
		name = "Dry Wet",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "Threshold",
		min = -60,
		max = 0,
		default = -12,
		changed = function(val)
			b = 10 ^ (val / 20.0)
			print(b)
		end,
	},
	{
		name = "Attack",
		min = 1,
		max = 200,
		default = 25,
		changed = function(val)
			attack = timeConstant(val)
		end,
	},
	{
		name = "Release",
		min = 1,
		max = 400,
		default = 200,
		changed = function(val)
			release = timeConstant(val)
		end,
	},
	{
		name = "Gain",
		min = 0,
		max = 48,
		default = 0,
		changed = function(val)
			c = 10 ^ (val / 20.0)
		end,
	},
})

params.resetToDefaults()
