require("include/protoplug")
local cbFilter = require("include/dsp/cookbook_svf")

-- basic implementation of Jiles-Atherton model,
-- no bias correction, tape head simulation, or tape speed control

-- TODO: This is just doing forward euler so might not  be unconditionally stable!

local balance = 1

local a = 0
local b = 0

local c = 0.35
local alpha = 0.28
local k = 1

function sgn(x)
	if x > 0 then
		return 1
	else
		return -1
	end
end

function softclip(x)
	s = math.max(math.min(x, 3), -3)
	return s * (27 + s * s) / (27 + 9 * s * s)
end

stereoFx.init()
function stereoFx.Channel:init()
	self.prev = 0
	self.m = 0
	self.m_irr = 0
	self.high = cbFilter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
	self.pre = cbFilter({ type = "tilt", f = 400, gain = 6, Q = 0.4 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = self.pre.process(samples[i] * a * 0.4)
		--local s = samples[i] * a
		local diff = s - self.prev
		self.prev = s

		local h_eff = s + alpha * self.m
		local m_anh = math.tanh(h_eff / alpha)

		--local delta = sgn(diff)

		-- possible divide by zero?
		--local d_m_irr = diff * (m_anh - self.m_irr) / (k * delta - alpha * (m_anh - self.m_irr))

		local d_m_irr = math.abs(diff) * (m_anh - self.m_irr) / k

		-- leaky integration to prevent build-up
		self.m_irr = self.m_irr * 0.99 + d_m_irr

		local m_rev = c * (m_anh - self.m_irr)

		self.m = m_rev + self.m_irr

		local out = self.m

		out = self.high.process(out)
		out = out * b / a

		samples[i] = (1.0 - balance) * samples[i] + balance * out
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
		min = -12,
		max = 12,
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

params.resetToDefaults()
