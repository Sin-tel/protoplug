-- BBD using the same logic as reduction.lua but reading/writing from a buffer between stages

require("include/protoplug")

local Polyphase = require("include/dsp/polyphase")
local Filter = require("include/dsp/cookbook_svf")
local COEFS = Polyphase.presets.coef_8

local sample_rate = 44100
local inv_2sr = 1.0 / 88200
plugin.addHandler("prepareToPlay", function()
	sample_rate = plugin.getSampleRate()
	inv_2sr = 1.0 / (2.0 * sample_rate)
end)

-- BBD length
local STAGES = 4096

-- parameters
local clock_rate = 10000
local feedback_amt = 0.0
local balance = 0.5
local use_filters = true

local even = 1 / 8
local odd = 1 / 18

local function dist(x)
	if x > 1 then
		return 1 - odd - even
	elseif x < -1 then
		return -1 + odd - even
	else
		return x - even * x * x - odd * x * x * x
	end
end

stereoFx.init()
function stereoFx.Channel:init()
	self.accum = 0.
	self.prev_in = 0.
	self.prev = 0.
	self.s = 0.

	-- note: 0-indexed!
	self.buffer = {}
	for i = 0, STAGES do
		self.buffer[i] = 0.0
	end
	-- self.buffer = ffi.new("float[4096]")

	-- write pointer
	self.head = 0

	-- 2x oversampling
	self.upsampler = Polyphase.new(COEFS)
	self.downsampler = Polyphase.new(COEFS)

	self.pre_lp = Filter({ type = "lp", f = 3000, Q = 0.7 })
	self.post_lp = Filter({ type = "lp", f = 3000, Q = 0.7 })

	self.high = Filter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
end

function stereoFx.Channel:tick(x)
	local step = clock_rate * inv_2sr

	self.accum = self.accum + step

	local out = self.s

	while self.accum >= 1.0 do
		self.accum = self.accum - 1.0

		-- input interpolation
		local a = self.accum / step
		local x_lerp = x * (1.0 - a) + self.prev_in * a

		-- bbd
		self.buffer[self.head] = x_lerp

		self.head = self.head + 1
		if self.head >= STAGES then
			self.head = 0
		end

		local delayed_sample = self.buffer[self.head]

		-- output interpolation
		local prev_s = self.s
		self.s = delayed_sample

		out = prev_s * (1.0 - a) + self.s * a
	end

	self.prev_in = x
	return out
end

function stereoFx.Channel:processBlock(samples, smax)
	if use_filters then
		local cutoff = math.max(1000, clock_rate * 0.45)
		self.pre_lp.update({ f = cutoff })
		self.post_lp.update({ f = cutoff })
	end

	for i = 0, smax do
		local in_s = samples[i]

		local s = in_s + self.prev * feedback_amt

		if use_filters then
			s = self.pre_lp.process(s)
		end

		s = s + 0.001 * (math.random() - 0.5)
		s = dist(s)
		-- s = s + 0.02 * math.abs(s)
		s = self.high.process(s)

		local u1, u2 = self.upsampler.upsample(s)
		u1 = self:tick(u1)
		u2 = self:tick(u2)
		local out = self.downsampler.downsample(u1, u2)

		if use_filters then
			out = self.post_lp.process(out)
		end

		self.prev = out

		samples[i] = in_s * (1 - balance) + out * balance
	end
end

params = plugin.manageParams({
	{
		name = "Clock Rate",
		min = 2000,
		max = 40000,
		default = 15000,
		changed = function(val)
			clock_rate = val
		end,
	},
	{
		name = "Feedback",
		min = 0,
		max = 1.0,
		default = 0.4,
		changed = function(val)
			feedback_amt = val
		end,
	},
	{
		name = "dry/wet",
		min = 0,
		max = 1,
		default = 0.5,
		changed = function(val)
			balance = val
		end,
	},
})

-- params.resetToDefaults()
