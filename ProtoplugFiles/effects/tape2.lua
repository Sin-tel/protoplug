require("include/protoplug")
local cbFilter = require("include/dsp/cookbook_svf")
local Upsampler31 = require("include/dsp/upsampler_31")
local Downsampler59 = require("include/dsp/downsampler_59")

-- basic implementation of Jiles-Atherton model,
-- no bias correction, tape head simulation, or tape speed control

-- TODO: This is just doing forward euler so might not  be unconditionally stable!

local balance = 1

local a = 0
local b = 0

local c = 0.5
local alpha = 0.1
local a_mag = 0.28
local k = 1

stereoFx.init()
function stereoFx.Channel:init()
	self.prev = 0
	self.m = 0
	self.m_irr = 0

	self.pre = cbFilter({ type = "ls", f = 600, gain = -6, Q = 0.5 })
	-- self.low = cbFilter({ type = "lp", f = 15000, Q = 0.7 })
	self.high = cbFilter({ type = "hp", f = 10, Q = 0.7 })

	self.upsampler = Upsampler31()
	self.downsampler = Downsampler59()
end

function stereoFx.Channel:tick(s)
	local diff = s - self.prev
	self.prev = s

	local h_eff = s + alpha * self.m
	local m_anh = math.tanh(h_eff / a_mag)

	local d_m_irr = math.sqrt(diff * diff + 0.001) * (m_anh - self.m_irr) / k

	-- leaky integration to prevent build-up
	self.m_irr = self.m_irr * 0.99 + d_m_irr

	local m_rev = c * (m_anh - self.m_irr)

	self.m = m_rev + self.m_irr

	return self.m
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i] * a
		s = self.pre.process(s * 0.42)
		-- s = self.low.process(s)

		s = s + math.random() * 0.001 + 0.01

		local u1, u2 = self.upsampler.tick(s)

		u1 = self:tick(u1)
		u2 = self:tick(u2)

		s = self.downsampler.tick(u1, u2)

		s = self.high.process(s)

		s = s * b / a

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
		min = -18,
		max = 18,
		default = 0,
		changed = function(val)
			a = math.pow(10, val / 20)
		end,
	},
	{
		name = "output",
		min = -12,
		max = 12,
		default = 0,
		changed = function(val)
			b = math.pow(10, val / 20)
		end,
	},
})

-- params.resetToDefaults()
