require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")
local OnePole = require("include/dsp/onepole")

local gain_in = 1
local gain_out = 1
local b = 0
local c = 0

local delta = 500 / 44100

local function sgn(x)
	if x >= 0 then
		return 1
	else
		return -1
	end
end

local function softclip(x)
	local v = math.abs(x)
	return sgn(x) * (v * v * v / (1 + v * v)) ^ (1 / 3)
end

stereoFx.init()
function stereoFx.Channel:init()
	self.s = 0
	self.prev = 0
	self.mag = 0

	self.mag_filter = OnePole({ type = "lp", f = 43 })

	self.high = Filter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = self.high.process(samples[i] * gain_in)

		-- integrate
		self.s = self.s + s * delta

		local u = self.s + b + c * 0.1 * math.tanh(self.mag * 10)
		u = softclip(u)

		self.mag = self.mag_filter.process(u)

		-- differatiate
		local out = (u - self.prev) / delta
		self.prev = u

		samples[i] = out * gain_out
	end
end

params = plugin.manageParams({
	{
		name = "Gain",
		min = -24,
		max = 12,
		changed = function(val)
			gain_in = 10 ^ (val / 20)
			gain_out = 10 ^ (-val / 20)
		end,
	},
	{
		name = "bias",
		min = 0,
		max = 1,
		changed = function(val)
			b = 0.2 * val * val
		end,
	},
	{
		name = "hysteresis",
		min = 0,
		max = 1,
		changed = function(val)
			c = 0.95 * val * val
		end,
	},
})
