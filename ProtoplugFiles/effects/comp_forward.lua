-- simple RMS/peak feed forward compressor, with a very soft kneee

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local b = 1
local c = 1

local expFactor = -1000.0 / 44100

local balance = 0.0

local is_rms = false

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local attack = timeConstant(20)
local release = timeConstant(80)

stereoFx.init()
function stereoFx.Channel:init(is_left)
	self.peak = 0
	self.is_left = is_left
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]
		local peak
		if is_rms then
			peak = inp * inp
		else
			peak = math.abs(inp)
		end

		if peak > self.peak then
			self.peak = self.peak - (self.peak - peak) * attack
		else
			self.peak = self.peak - (self.peak - peak) * release
		end

		local p
		if is_rms then
			p = math.sqrt(self.peak) * 1.41
		else
			p = self.peak * 1.57
		end

		local g = (1 - balance) + balance * b * c / (p + b)

		if self.is_left then
			samples[i] = g * inp
		else
			samples[i] = g
		end
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
		default = -24,
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
		name = "MakeUp",
		min = 0,
		max = 36,
		default = 0,
		changed = function(val)
			c = 10 ^ (val / 20.0)
		end,
	},

	{
		name = "peak / RMS",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			is_rms = val > 0.5
		end,
	},
})

--params.resetToDefaults()
