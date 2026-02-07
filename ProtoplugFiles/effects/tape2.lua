require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")
local Polyphase = require("include/dsp/polyphase")
local COEFS = Polyphase.presets.coef_8

-- modified J-A model with better stability

local balance = 1

local gain = 0
local gain_inv = 0
local gain_post = 0

local c = 0.5
local alpha = 0.1
local a_mag = 0.28
local k = 1

local L_MAX = 3.646738596
local function tanh(x)
	if x > L_MAX then
		x = L_MAX
	elseif x < -L_MAX then
		x = -L_MAX
	end
	-- PadeApproximant[tanh(x),{x,0,{5,4}}]
	local x2 = x * x
	return ((x2 + 105) * x2 + 945) * x / ((15 * x2 + 420) * x2 + 945)
end

stereoFx.init()
function stereoFx.Channel:init()
	self.prev = 0
	self.m = 0
	self.m_irr = 0

	-- self.tape_filter = Filter({ type = "ls", f = 600, gain = -6, Q = 0.5 })
	self.high = Filter({ type = "hp", f = 10, Q = 0.7 })

	self.pre_emph = Filter({ type = "hs", f = 1000, gain = 10, Q = 0.7 })
	self.post_emph = Filter({ type = "hs", f = 1000, gain = -10, Q = 0.7 })

	-- high rolloff
	self.low = Filter({ type = "ls", f = 17000, Q = 0.707 })

	self.upsampler = Polyphase.new(COEFS)
	self.downsampler = Polyphase.new(COEFS)
end

function stereoFx.Channel:tick(s)
	local diff = s - self.prev
	self.prev = s

	local h_eff = s + alpha * self.m

	local m_anh = tanh(h_eff / a_mag)
	-- local k2 = math.sqrt(diff * diff + 0.0001) / k
	local k2 = math.abs(diff) / k
	k2 = 1.0 - math.exp(-k2)
	local d_m_irr = k2 * (m_anh - self.m_irr)
	self.m_irr = self.m_irr + d_m_irr

	local m_rev = c * (m_anh - self.m_irr)

	self.m = m_rev + self.m_irr

	return self.m
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i] * gain

		s = self.pre_emph.process(s)
		s = self.low.process(s)
		s = s * 0.42
		s = self.tape_filter.process(s)

		-- s = s + math.random() * 0.001 + 0.01

		local u1, u2 = self.upsampler.upsample(s)
		u1 = self:tick(u1)
		u2 = self:tick(u2)
		s = self.downsampler.downsample(u1, u2)

		-- s = self.tape_filter.process(s)
		s = self.high.process(s)
		s = self.post_emph.process(s)

		s = s * gain_post * gain_inv

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
				gain_inv = math.pow(10, -val / 40)
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
		name = "pre-emphasis",
		min = 0,
		max = 12,
		default = 10,
		changed = function(val)
			stereoFx.LChannel.pre_emph.update({ gain = val })
			stereoFx.RChannel.pre_emph.update({ gain = val })

			stereoFx.LChannel.post_emph.update({ gain = -val })
			stereoFx.RChannel.post_emph.update({ gain = -val })
		end,
	},
})

-- params.resetToDefaults()
