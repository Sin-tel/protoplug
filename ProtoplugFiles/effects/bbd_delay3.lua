-- same as bbd_delay2 but with compander and lfo modulation

require("include/protoplug")

local Filter = require("include/dsp/cookbook_svf")
local Polyphase = require("include/dsp/polyphase")
local COEFS = Polyphase.presets.coef_8

-- global dsp
local sample_rate = 44100
local inv_2sr = 1.0 / 88200

local n_stages = 4096
local MAX_STAGES = 8192

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
local even = 0.05 --0.025
local odd = 0.02 --0.01

local function clip(x)
	local s = math.min(math.max(x, -5 / 4), 5 / 4)
	return s - (256. / 3125.) * s ^ 5
end

local function dist(x)
	x = clip(x)
	return x - even * x * x - odd * x * x * x
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
	self.x1 = 0.
	self.prev = 0.
	self.s = 0.
	self.jitter = 1.0

	self.lfo_phase = 0.

	self.buffer = {}
	for i = 0, MAX_STAGES do
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
	x = dist(x * 0.5) * 2

	local out = self.s

	while self.accum >= 1.0 do
		self.accum = self.accum - 1.0

		-- input interpolation
		local a = self.accum / step
		local x_lerp = x * (1.0 - a) + self.x1 * a

		-- bucket brigade
		self.buffer[self.head] = x_lerp

		self.head = self.head + 1
		self.head = self.head % MAX_STAGES

		local read = (self.head - n_stages) % MAX_STAGES

		local delayed_sample = self.buffer[read]

		-- output interpolation
		local s1 = self.s
		self.s = delayed_sample

		out = s1 * (1.0 - a) + self.s * a

		-- update clock jitter
		if jitter_amount > 0 then
			local noise = math.random() - 0.5
			self.jitter = 1.0 + (noise * jitter_amount)
		else
			self.jitter = 1.0
		end
	end

	self.x1 = x
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
		-- s = s + 0.003 * (math.random() - 0.5)

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
		max = 64000,
		default = 15000,
		changed = function(val)
			clock_rate = math.floor(val / 4000) * 4000
			if clock_rate < 2000 then
				clock_rate = 2000
			end
			print(clock_rate)
		end,
	},

	-- {
	-- 	name = "Clock Rate",
	-- 	type = "list",
	-- 	values = { "2k", "3k", "4k", "6k", "8k", "12k", "16k", "24k", "32k", "48k", "64k" },
	-- 	default = "12k",
	-- 	changed = function(val)
	-- 		clock_rate = tonumber(val:sub(1, val:len() - 1)) * 1000
	-- 		print(clock_rate)
	-- 	end,
	-- },
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
			jitter_amount = 0.2 * val * val
		end,
	},

	{
		name = "double",
		type = "list",
		values = { "off", "on" },
		default = "off",
		changed = function(val)
			if val == "on" then
				n_stages = 8192
			else
				n_stages = 4096
			end
		end,
	},
})

-- params.resetToDefaults()
