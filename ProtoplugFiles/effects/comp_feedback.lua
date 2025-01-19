--[[
Feedback compressor
1 sample delay feedback loop
]]
require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

local a = 50.0
local b = 0.5
local c = 1

local expFactor = -1000.0 / 44100

local drywet = 0.0

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local attack = timeConstant(20)
local release = timeConstant(80)

stereoFx.init()
function stereoFx.Channel:init(is_left)
	self.gain_p = 0
	self.gain_p2 = 0
	self.is_left = is_left
	self.gain_filter = Filter({ type = "lp", f = 10, Q = 0.5 })
	self.high = Filter({ type = "hp", f = 100, gain = 0, Q = 0.5 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s_in = samples[i]

		local s = self.high.process(s_in)
		local peak = math.abs(s * b) * self.gain_p

		local gain = 0.5 - 0.5 * math.tanh(a * (peak - 1))
		-- peak = math.max(0, peak - 1)
		-- local gain = math.exp(-a * peak)

		-- self.gain_p2 = self.gain_filter.process(gain)
		self.gain_p2 = self.gain_p2 - (self.gain_p2 - gain) * attack

		if self.gain_p2 < self.gain_p then
			-- self.gain_p = self.gain_p - (self.gain_p - self.gain_p2) * attack
			self.gain_p = self.gain_p2
		else
			self.gain_p = self.gain_p - (self.gain_p - self.gain_p2) * release
		end

		local g = self.gain_p

		-- local s_out = math.tanh(s_in * g * c) * drywet + samples[i] * (1.0 - drywet)
		local s_out = (s_in * g * c) * drywet + s_in * (1.0 - drywet)

		samples[i] = s_out
		-- if self.is_left then
		-- 	samples[i] = s_out
		-- else
		-- 	samples[i] = g
		-- end
	end
end

params = plugin.manageParams({
	{
		name = "Dry Wet",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			drywet = val
		end,
	},
	{
		name = "Feedback",
		min = -2,
		max = 2,
		default = 0,
		changed = function(val)
			a = math.exp(val)
		end,
	},
	{
		name = "Threshold",
		min = -48,
		max = 0,
		default = -12,
		changed = function(val)
			b = 10 ^ (-val / 20.0)
		end,
	},
	{
		name = "Attack",
		min = 0.1,
		max = 25,
		default = 12,
		changed = function(val)
			attack = timeConstant(val)
		end,
	},
	-- {
	-- 	name = "Attack",
	-- 	min = 0,
	-- 	max = 2.5,
	-- 	default = 12,
	-- 	changed = function(val)
	-- 		local f = 0.6 * (10 ^ (2.5 - val))
	-- 		print(f)
	-- 		stereoFx.RChannel.gain_filter.update({ f = f })
	-- 		stereoFx.LChannel.gain_filter.update({ f = f })
	-- 	end,
	-- },
	{
		name = "Release",
		min = 1,
		max = 250,
		default = 120,
		changed = function(val)
			release = timeConstant(val)
		end,
	},
	{
		name = "MakeUp",
		min = 0,
		max = 24,
		default = 0,
		changed = function(val)
			c = 10 ^ (val / 20.0)
		end,
	},
	{
		name = "Highpass SC",
		min = 10,
		max = 140,
		default = 12,
		changed = function(val)
			local f = val
			stereoFx.RChannel.high.update({ f = f })
			stereoFx.LChannel.high.update({ f = f })
		end,
	},
})

-- params.resetToDefaults()
