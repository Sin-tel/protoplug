-- tape with companding noise reduction

require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")
local Polyphase = require("include/dsp/polyphase")
local COEFS = Polyphase.presets.coef_8

-- global DSP
local sample_rate = 44100

-- parameters
local balance = 1.0
local gain = 1.0
local gain_post = 1.0
local gain_inv = 1.0
local compander_on = true

-- tape params
local c = 0.5
local alpha = 0.1
local a_mag = 0.28
local k = 1

-- ms to tau
local T_LN = 4605.1704
local function time_constant(t)
	local denom = sample_rate * t
	return 1.0 - math.exp(-T_LN / denom)
end

-- compander envelope
local env_t = 60.0
local env_s = time_constant(env_t)

plugin.addHandler("prepareToPlay", function()
	sample_rate = plugin.getSampleRate()
	env_s = time_constant(env_t)
end)

stereoFx.init()
function stereoFx.Channel:init()
	self.prev = 0
	self.m = 0
	self.m_irr = 0

	-- envelopes
	self.env_in = 1.0
	self.env_out = 0

	-- emphasis filters for noise shaping
	self.pre_emph = Filter({ type = "hs", f = 1000, gain = 10, Q = 0.7 })
	self.post_emph = Filter({ type = "hs", f = 1000, gain = -10, Q = 0.7 })

	-- compensate tape emulation response
	self.tape_filter = Filter({ type = "ls", f = 600, gain = -6, Q = 0.5 })
	-- DC killer
	self.high = Filter({ type = "hp", f = 10, Q = 0.7 })

	self.upsampler = Polyphase.new(COEFS)
	self.downsampler = Polyphase.new(COEFS)
end

function stereoFx.Channel:tick(s)
	local diff = s - self.prev
	self.prev = s

	local h_eff = s + alpha * self.m
	local m_anh = math.tanh(h_eff / a_mag)

	-- stability fix
	local k2 = math.sqrt(diff * diff + 0.001) / k
	k2 = 1.0 - math.exp(-k2)
	local d_m_irr = k2 * (m_anh - self.m_irr)

	self.m_irr = self.m_irr + d_m_irr

	local m_rev = c * (m_anh - self.m_irr)

	self.m = m_rev + self.m_irr

	return self.m
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		-- pre-filter
		s = s * gain
		s = self.pre_emph.process(s)

		if compander_on then
			-- 2:1 compression (feedback)
			s = s / (self.env_in + 1e-4)
			local env_in = math.abs(s)
			self.env_in = self.env_in - (self.env_in - env_in) * env_s

			s = 0.25 * s
		end

		-- noise
		s = s + math.random() * 0.001

		-- run tape emulation
		s = self.tape_filter.process(s * 0.42)
		local u1, u2 = self.upsampler.upsample(s)
		u1 = self:tick(u1)
		u2 = self:tick(u2)
		s = self.downsampler.downsample(u1, u2)
		s = self.high.process(s)

		if compander_on then
			s = 4 * s

			-- output 1:2 expansion (feedforward)
			local env_out = math.abs(s)
			self.env_out = self.env_out - (self.env_out - env_out) * env_s
			s = s * (self.env_out + 1e-4)
		end

		-- post-filter
		s = self.post_emph.process(s)
		s = s * gain_inv
		s = s * gain_post

		samples[i] = (1.0 - balance) * samples[i] + balance * s
	end
end

params = plugin.manageParams({
	{
		name = "dry/wet",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "drive",
		min = -24,
		max = 24,
		default = 0,
		changed = function(val)
			gain = math.pow(10, val / 20)
			if val > 0 then
				gain_inv = math.pow(10, -val / 20)
			else
				gain_inv = math.pow(10, -val / 20)
			end
		end,
	},
	{
		name = "output",
		min = -12,
		max = 12,
		default = 0,
		changed = function(val)
			gain_post = math.pow(10, val / 20)
		end,
	},

	{
		name = "compander",
		type = "list",
		values = { "off", "on" },
		default = "on",
		changed = function(val)
			compander_on = (val == "on")
		end,
	},
})

-- params.resetToDefaults()
