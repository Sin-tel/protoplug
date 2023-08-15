require("include/protoplug")
local cbFilter = require("include/dsp/cookbook_svf")

local balance = 1

function softclip(x)
	local s = math.min(math.max(x, -3.0), 3.0)
	return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)
end

function tube(x)
	local s = math.max(x, -1.6277)
	local s = math.min(s, 1.8849)
	local s = s + s * s * (1 - 0.253 * s * s * (1 - 0.091 * s * s * (1 - 0.177 * s)))
	return s
end

stereoFx.init()
function stereoFx.Channel:init()
	self.high = cbFilter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
	self.low = cbFilter({ type = "lp", f = 5, Q = 1.1 })
	self.low2 = cbFilter({ type = "lp", f = 450, Q = 0.7 })
	self.pre = cbFilter({ type = "tilt", f = 300, gain = 3, Q = 0.4 })
	self.post = cbFilter({ type = "tilt", f = 300, gain = -3, Q = 0.4 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i] * a

		local w = self.low2.process(s)
		w = math.max(0, w)

		w = self.low.process(w)
		s = self.pre.process(s)

		local out = tube(s + 0.9 * w + 0.2)
		out = self.high.process(out)

		out = self.post.process(out)

		out = softclip(out)

		out = out / a * b

		samples[i] = (1.0 - balance) * samples[i] + balance * out
	end
end

params = plugin.manageParams({
	{
		name = "dry/wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "drive",
		min = -12,
		max = 24,
		changed = function(val)
			a = math.pow(10, val / 20)
		end,
	},
	{
		name = "output",
		min = 0,
		max = 12,
		changed = function(val)
			b = math.pow(10, val / 20)
		end,
	},
})
