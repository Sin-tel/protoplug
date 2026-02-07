require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

local function clip(x)
	local s = math.min(math.max(x, -5 / 4), 5 / 4)
	return s - (256. / 3125.) * s ^ 5
end

local gain_in = 0.5
local gain_out = 1

local threshold = 0.15

local expFactor = -1000.0 / 44100

local balance = 0.0

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local attack = timeConstant(20)
local release = timeConstant(80)

local clip_a = timeConstant(40)
local clip_l = 0
local clip_r = 0

local env_1 = 0

local mix = 0.02

local high_in_l = Filter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
local high_in_r = Filter({ type = "hp", f = 10, gain = 0, Q = 0.7 })

local high_out_l = Filter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
local high_out_r = Filter({ type = "hp", f = 10, gain = 0, Q = 0.7 })

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local input_l = samples[0][i]
		local input_r = samples[1][i]

		local s_l = input_l * gain_in
		local s_r = input_r * gain_in

		-- sidechain filter
		local p_l = high_in_l.process(s_l)
		local p_r = high_in_r.process(s_r)

		-- stereo link peak
		local peak = math.max(math.abs(p_l), math.abs(p_r))

		-- release
		if env_1 < peak then
			env_1 = peak
		else
			--local rf = 0.2 + 0.8 / (1 + env_1)
			env_1 = env_1 - (env_1 - peak) * release
		end

		local g = env_1 * 1.5 + 1e-7

		g = mix + (1 - mix) * clip(g) / g

		s_l = s_l * g
		s_r = s_r * g

		-- clipping with negative feedback bias
		local wet_l = clip(s_l + 0.5 - 20 * clip_l) - 0.5
		clip_l = clip_l + (wet_l - clip_l) * clip_a

		local wet_r = clip(s_r + 0.5 - 20 * clip_r) - 0.5
		clip_r = clip_r + (wet_r - clip_r) * clip_a

		wet_l = high_out_l.process(wet_l)
		wet_l = wet_l * gain_out
		local out_l = wet_l * balance + input_l * (1.0 - balance)

		wet_r = high_out_r.process(wet_r)
		wet_r = wet_r * gain_out
		local out_r = wet_r * balance + input_r * (1.0 - balance)

		samples[0][i] = out_l
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
		name = "Gain in",
		min = 0,
		max = 48,
		default = 0,
		changed = function(val)
			gain_in = 2 * 10 ^ (val / 20.0)
		end,
	},

	{
		name = "Gain out",
		min = -18,
		max = 0,
		default = 0,
		changed = function(val)
			gain_out = 0.5 * 10 ^ (val / 20.0)
		end,
	},

	{
		name = "Release",
		min = 2,
		max = 200,
		default = 60,
		changed = function(val)
			release = timeConstant(val)
		end,
	},

	{
		name = "Highpass SC",
		min = 10,
		max = 250,
		default = 20,
		changed = function(val)
			high_in_l.update({ f = val })
			high_in_r.update({ f = val })
		end,
	},
})

-- params.resetToDefaults()
