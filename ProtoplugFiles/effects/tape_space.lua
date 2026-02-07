-- tape loop emulation

require("include/protoplug")

local Filter = require("include/dsp/cookbook_svf")
local Polyphase = require("include/dsp/polyphase")
local COEFS = Polyphase.presets.coef_8

local sample_rate = 44100
plugin.addHandler("prepareToPlay", function()
	sample_rate = plugin.getSampleRate()
end)

local TWO_PI = 2 * math.pi

-- about a second at 44.1kHz
local LEN = 40000

local drive = 1.0
local drive_inv = 1.0

-- parameters
local speed_target = 1
local feedback_amt = 0.0
local balance = 0.5

local h1_gain = 0.
local h2_gain = 0.
local h3_gain = 1.

-- tape params
local c = 0.5
local alpha = 0.1
local a_mag = 0.28
local k = 1
local use_filters = true

-- wow
local lfo_freq = TWO_PI * 0.4 / sample_rate
local lfo_mod = 0.1

-- flutter
local flutter_depth = 0.5
local next_rate = 0.5
local flutter_rate = 0.5
local flutter_trim = 0.00581
local sweep_trim = (0.0005 * flutter_depth)
local fl_rate_change = 0.006
local sweep = 0

local jitter = 0.

local function hermite4(y0, y1, y2, y3, a)
	local c0 = y1
	local c1 = 0.5 * (y2 - y0)
	local c2 = y0 - 2.5 * y1 + 2.0 * y2 - 0.5 * y3
	local c3 = 0.5 * (y3 - y0) + 1.5 * (y1 - y2)

	return ((c3 * a + c2) * a + c1) * a + c0
end

stereoFx.init()
function stereoFx.Channel:init(left)
	self.speed = 1.0
	self.accum = 0.
	self.prev = 0.
	self.prev_in = 0.
	self.x1 = 0.
	self.x2 = 0.
	self.x3 = 0.

	self.h1_gain = 0.
	self.h2_gain = 0.
	self.h3_gain = 1.
	self.lfo_mod = 0.

	-- wow
	self.lfo_phase_offset = 0
	if left then
		self.lfo_phase_offset = 0.5 * math.pi
	end
	self.lfo_phase = 0.

	-- tape
	self.prev_t = 0
	self.m = 0
	self.m_irr = 0

	-- note: 0-indexed!
	self.buffer = {}
	for i = 0, LEN do
		self.buffer[i] = 0.0
	end

	-- write pointer
	self.head = 0

	-- 2x oversampling
	self.upsampler = Polyphase.new(COEFS)
	self.downsampler = Polyphase.new(COEFS)

	self.speed_filter = Filter({ type = "lp", f = 0.6, Q = 0.5 })

	-- 4 pole butterworth cascades
	self.pre_lp1 = Filter({ type = "lp", oversample = 2, f = 2000, Q = 0.5412 })
	self.pre_lp2 = Filter({ type = "lp", oversample = 2, f = 2000, Q = 1.3066 })

	self.post_lp1 = Filter({ type = "lp", oversample = 2, f = 2000, Q = 0.5412 })
	self.post_lp2 = Filter({ type = "lp", oversample = 2, f = 2000, Q = 1.3066 })

	self.noise_filter = Filter({ type = "lp", f = 850, Q = 0.7 })

	self.fb_filter = Filter({ type = "hp", f = 200, Q = 0.7 })
	self.fb_filter2 = Filter({ type = "hs", f = 2700, gain = -3, Q = 0.7 })

	-- DC killer
	self.high = Filter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
end

function stereoFx.Channel:read(h)
	local h_int = math.floor(h)
	local frac = h - h_int
	local y0 = self.buffer[(h_int - 1) % LEN]
	local y1 = self.buffer[h_int % LEN]
	local y2 = self.buffer[(h_int + 1) % LEN]
	local y3 = self.buffer[(h_int + 2) % LEN]
	return hermite4(y0, y1, y2, y3, frac)
end

function stereoFx.Channel:tick_magnetic(s)
	local diff = s - self.prev_t
	self.prev_t = s

	local h_eff = s + alpha * self.m
	local m_anh = math.tanh(h_eff / a_mag)

	local k2 = math.sqrt(diff * diff + 0.001) / k
	k2 = 1.0 - math.exp(-k2)
	self.d = self.m_irr + k2 * (m_anh - self.m_irr)

	local m_rev = c * (m_anh - self.m_irr)

	self.m = m_rev + self.m_irr

	return self.m
end

function stereoFx.Channel:tick_tape(x)
	if use_filters then
		x = self.pre_lp1.process(x)
		x = self.pre_lp2.process(x)
	end

	local step = self.speed
	self.accum = self.accum + step

	x = self:tick_magnetic(x * drive) * drive_inv

	while self.accum >= 1.0 do
		self.accum = self.accum - 1.0

		-- input interpolation
		local a = self.accum / (step + 1e-6)
		local x_interp = hermite4(x, self.x1, self.x2, self.x3, a)

		self.buffer[self.head] = x_interp
		self.head = (self.head + 1) % LEN
	end
	self.x3 = self.x2
	self.x2 = self.x1
	self.x1 = x

	-- output interpolation
	local read = self.head + self.accum

	self.lfo_phase = self.lfo_phase + 0.27 * TWO_PI * self.speed / LEN

	local h1_mod = 400.0 * self.lfo_mod * math.sin(self.lfo_phase * 1.53 + self.lfo_phase_offset)
	local h2_mod = 400.0 * self.lfo_mod * math.sin(self.lfo_phase * 1.21 + self.lfo_phase_offset)
	local h3_mod = 400.0 * self.lfo_mod * math.sin(self.lfo_phase * 0.97 + self.lfo_phase_offset)

	local head1 = read - LEN * 0.270 + h1_mod
	local head2 = read - LEN * 0.600 + h2_mod
	local head3 = read - LEN * 0.951 + h3_mod

	local h1 = self:read(head1)
	local h2 = self:read(head2)
	local h3 = self:read(head3)

	local out = h1 * self.h1_gain + h2 * self.h2_gain + h3 * self.h3_gain

	if use_filters then
		out = self.post_lp1.process(out)
		out = self.post_lp2.process(out)
	end

	return out
end

function stereoFx.Channel:processBlock(samples, smax)
	if use_filters then
		-- set all filters to the tape internal nyquist
		local cutoff = math.max(1000, speed_target * 20000)
		self.pre_lp1.update({ f = cutoff })
		self.pre_lp2.update({ f = cutoff })
		self.post_lp1.update({ f = cutoff })
		self.post_lp2.update({ f = cutoff })
	end

	for i = 0, smax do
		-- parameter interpolation
		self.h1_gain = self.h1_gain + 0.01 * (h1_gain - self.h1_gain)
		self.h2_gain = self.h2_gain + 0.01 * (h2_gain - self.h2_gain)
		self.h3_gain = self.h3_gain + 0.01 * (h3_gain - self.h3_gain)
		self.lfo_mod = self.lfo_mod + 0.01 * (lfo_mod - self.lfo_mod)

		self.speed = self.speed_filter.process(speed_target)

		local mod = 0.0

		-- jitter
		mod = mod + 0.5 * jitter * self.noise_filter.process(math.random() - 0.5)

		-- flutter
		flutter_rate = next_rate * fl_rate_change + flutter_rate * (1 - fl_rate_change)
		sweep = sweep + flutter_rate * flutter_trim
		sweep = sweep + sweep * sweep_trim
		if sweep >= TWO_PI then
			sweep = 0.0
			next_rate = 0.02 + (math.random() * 0.98)
		end
		mod = mod + 0.03 * flutter_depth * math.sin(sweep)

		-- add modulation to speed
		self.speed = self.speed * (1.0 + mod)

		-- input
		local in_s = samples[i]
		local s = in_s + self.prev * feedback_amt

		-- tweak to get unity gain
		s = s * 0.47

		s = self.fb_filter.process(s)
		s = self.fb_filter2.process(s)

		-- noise and DC bias
		s = s * (1.0 + math.random() * 0.01)
		s = s + 0.01

		local u1, u2 = self.upsampler.upsample(s)
		u1 = self:tick_tape(u1)
		u2 = self:tick_tape(u2)
		local out = self.downsampler.downsample(u1, u2)

		out = self.high.process(out)

		self.prev = out

		samples[i] = in_s * (1 - balance) + out * balance
	end
end

params = plugin.manageParams({
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
		name = "speed",
		min = 0.25,
		max = 1.5,
		default = 1,
		changed = function(val)
			speed_target = val
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
		name = "drive",
		min = -12,
		max = 12,
		default = 0,
		changed = function(val)
			drive = 10 ^ (val / 20)
			drive_inv = 1 / drive
		end,
	},
	{
		name = "wow",
		min = 0,
		max = 1,
		default = 0.3,
		changed = function(val)
			lfo_mod = val * val
		end,
	},
	{
		name = "flutter",
		min = 0,
		max = 1,
		default = 0.5,
		changed = function(val)
			flutter_depth = val * val
			sweep_trim = (0.0005 * flutter_depth)
		end,
	},
	{
		name = "jitter",
		min = 0,
		max = 1,
		default = 0.5,
		changed = function(val)
			jitter = val * val
		end,
	},
	{
		name = "mode",
		type = "list",
		values = { "1", "2", "3", "1+3", "2+3" },
		default = "3",
		changed = function(val)
			if val == "1" then
				h1_gain = 1.0
				h2_gain = 0.0
				h3_gain = 0.0
			elseif val == "2" then
				h1_gain = 0.0
				h2_gain = 1.0
				h3_gain = 0.0
			elseif val == "3" then
				h1_gain = 0.0
				h2_gain = 0.0
				h3_gain = 1.0
			elseif val == "1+3" then
				h1_gain = 0.707
				h2_gain = 0.0
				h3_gain = 0.707
			elseif val == "2+3" then
				h1_gain = 0.0
				h2_gain = 0.707
				h3_gain = 0.707
			else
				assert(false, "unreachable")
			end
		end,
	},
})

-- params.resetToDefaults()
