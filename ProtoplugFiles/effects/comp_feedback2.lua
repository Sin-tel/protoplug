--[[
Feedback compressor
1 sample delay feedback loop
]]
require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

local function clip(x)
	local s = math.min(math.max(x, -5 / 4), 5 / 4)
	return s - (256. / 3125.) * s ^ 5
end

local gain_in = 0.5
local make_up = 1

local ratio = 4

local expFactor = -1000.0 / 44100

local balance = 0.0

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local attack = timeConstant(20)
local release = timeConstant(80)

local gain_p = 0
local gain_p2 = 0
local peak2 = 0
local high_l = Filter({ type = "hp", f = 100, gain = 0, Q = 0.7 })
local high_r = Filter({ type = "hp", f = 100, gain = 0, Q = 0.7 })

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local input_l = samples[0][i]
		local input_r = samples[1][i]

		local sl = high_l.process(input_l)
		local sr = high_r.process(input_r)

		-- stereo link peak
		local peak = math.max(math.abs(sl), math.abs(sr))
		peak = peak * 4 * gain_in * gain_p

		-- attack smoothing before threshold
		peak2 = peak2 - (peak2 - peak) * attack

		-- compute gain
		gain_p2 = 1 / (peak2 ^ ratio + 1)

		-- release
		if gain_p2 < gain_p then
			gain_p = gain_p2
		else
			gain_p = gain_p - (gain_p - gain_p2) * release
		end

		local g = gain_p

		local wet_l = clip(input_l * gain_in * g * make_up)
		local out_l = wet_l * balance + input_l * (1.0 - balance)

		local wet_r = clip(input_r * gain_in * g * make_up)
		local out_r = wet_r * balance + input_r * (1.0 - balance)

		samples[0][i] = out_l
		-- samples[1][i] = g
		samples[1][i] = out_r
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
		name = "Ratio",
		type = "list",
		values = { 2, 4, 10 },
		default = 4,
		changed = function(val)
			ratio = val
		end,
	},

	{
		name = "Gain in",
		min = 0,
		max = 48,
		default = 12,
		changed = function(val)
			gain_in = 10 ^ (val / 20.0)
		end,
	},
	{
		name = "Attack",
		min = 0.1,
		max = 50,
		default = 15,
		changed = function(val)
			attack = timeConstant(val * 5)
		end,
	},
	{
		name = "Release",
		min = 1,
		max = 500,
		default = 120,
		changed = function(val)
			release = timeConstant(val)
		end,
	},
	{
		name = "Gain out",
		min = -12,
		max = 12,
		default = 0,
		changed = function(val)
			make_up = 10 ^ (val / 20.0)
		end,
	},
	{
		name = "Highpass SC",
		min = 10,
		max = 250,
		default = 20,
		changed = function(val)
			high_l.update({ f = val })
			high_r.update({ f = val })
		end,
	},
})

-- params.resetToDefaults()
