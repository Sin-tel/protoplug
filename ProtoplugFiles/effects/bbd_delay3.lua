-- same as bbd_delay2 but with compander and lfo modulation

require("include/protoplug")

local Polyphase = require("include/dsp/polyphase")
local Filter = require("include/dsp/cookbook_svf")
local COEFS = Polyphase.presets.coef_8

-- global dsp
local sample_rate = 44100
local inv_2sr = 1.0 / 88200

local STAGES = 4096

-- parameters
local clock_rate = 10000
local feedback_amt = 0.0
local balance = 0.5
local use_filters = true
local jitter_amount = 0.0

local lfo_freq = 0.
local lfo_mod = 0

-- ms to tau
local T_LN = 4605.1704
local function time_constant(t)
	local denom = sample_rate * t
	return 1.0 - math.exp(-T_LN / denom)
end

local env_s = time_constant(100.0)

-- distortion
local even = 0.025
local odd = 0.01

local function dist(x)
	if x > 1 then
		return 1 - odd - even
	elseif x < -1 then
		return -1 + odd - even
	else
		return x - even * x * x - odd * x * x * x
	end
end

local function softclip(x)
	local s = math.min(math.max(x, -3.0), 3.0)
	return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)
end

plugin.addHandler("prepareToPlay", function()
	sample_rate = plugin.getSampleRate()
	inv_2sr = 1.0 / (2.0 * sample_rate)
	env_s = time_constant(100.0)
end)

stereoFx.init()
function stereoFx.Channel:init(left)
	self.lfo_phase_offset = 0
	if left then
		self.lfo_phase_offset = 0.5 * math.pi
	end
	self.accum = 0.
	self.prev_in = 0.
	self.prev = 0.
	self.s = 0.
	self.jitter = 1.0

	self.lfo_phase = 0.

	self.buffer = {}
	for i = 0, STAGES do
		self.buffer[i] = 0.0
	end
	self.head = 0

	-- envelopes
	self.env_in = 0
	self.env_out = 0

	-- 2x oversampling
	self.upsampler = Polyphase.new(COEFS)
	self.downsampler = Polyphase.new(COEFS)

	-- butterworth cascades
	self.pre_lp1 = Filter({ type = "lp", f = 2000, Q = 0.5412 })
	self.pre_lp2 = Filter({ type = "lp", f = 2000, Q = 1.3066 })

	self.post_lp1 = Filter({ type = "lp", f = 2000, Q = 0.5412 })
	self.post_lp2 = Filter({ type = "lp", f = 2000, Q = 1.3066 })

	-- DC blocker
	self.high = Filter({ type = "hp", f = 10, gain = 0, Q = 0.5 })
end

function stereoFx.Channel:tick(x)
	local lfo = math.sin(self.lfo_phase + self.lfo_phase_offset) * lfo_mod
	local rate = clock_rate * self.jitter * (1.0 + 0.05 * lfo)
	local step = rate * inv_2sr

	self.accum = self.accum + step

	-- input distortion
	x = dist(x)
	-- x = softclip(0.1 + x * 0.5) * 2.0

	local out = self.s

	while self.accum >= 1.0 do
		self.accum = self.accum - 1.0

		-- input interpolation
		local a = self.accum / step
		local x_lerp = x * (1.0 - a) + self.prev_in * a

		-- bucket brigade
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

		-- update clock jitter
		if jitter_amount > 0 then
			local noise = math.random() - 0.5
			self.jitter = 1.0 + (noise * jitter_amount)
		else
			self.jitter = 1.0
		end
	end

	self.prev_in = x
	return out
end

function stereoFx.Channel:processBlock(samples, smax)
	if use_filters then
		local cutoff = math.max(1000, clock_rate * 0.45)
		self.pre_lp1.update({ f = cutoff })
		self.pre_lp2.update({ f = cutoff })
		self.post_lp1.update({ f = cutoff })
		self.post_lp2.update({ f = cutoff })
	end

	for i = 0, smax do
		self.lfo_phase = self.lfo_phase + lfo_freq

		local in_s = samples[i]

		local fb_signal = self.prev * feedback_amt

		local s = in_s + fb_signal

		-- 2:1 compression (feedback)
		s = s / (self.env_in + 1e-4)
		local env_in = math.abs(s)
		self.env_in = self.env_in - (self.env_in - env_in) * env_s

		if use_filters then
			s = self.pre_lp1.process(s)
			s = self.pre_lp2.process(s)
		end

		-- noise
		s = s + 0.003 * (math.random() - 0.5)

		-- run the BBD with 2x oversampling
		local u1, u2 = self.upsampler.upsample(s)
		u1 = self:tick(u1)
		u2 = self:tick(u2)
		local out = self.downsampler.downsample(u1, u2)

		out = self.high.process(out)

		if use_filters then
			out = self.post_lp1.process(out)
			out = self.post_lp2.process(out)
		end

		-- output 1:2 expansion (feedforward)
		local env_out = math.abs(out)
		self.env_out = self.env_out - (self.env_out - env_out) * env_s
		out = out * (self.env_out + 1e-4)

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

	{
		name = "LFO Spd",
		--type = "int";
		min = 0.5,
		max = 7.0,
		changed = function(val)
			lfo_freq = 2 * math.pi * val / sample_rate
		end,
	},
	{
		name = "LFO Mod",
		--type = "int";
		min = 0,
		max = 1,
		changed = function(val)
			lfo_mod = val
		end,
	},

	{
		name = "Jitter",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			jitter_amount = 0.8 * val * val
		end,
	},
})

-- params.resetToDefaults()
