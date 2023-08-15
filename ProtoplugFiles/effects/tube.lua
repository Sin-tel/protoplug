require("include/protoplug")
local cbFilter = require("include/dsp/cookbook_svf")

local a = 0
local b = 0
local c = 0

local balance = 1

function tanhdx(x)
	local a = x * x
	return ((a + 105.0) * a + 945.0) / ((15.0 * a + 420.0) * a + 945.0)
end

function tube(x)
	return x * tanhdx(x - 0.5)
end

stereoFx.init()
function stereoFx.Channel:init()
	self.prev = 0
	self.high = cbFilter({ type = "hp", f = 20, gain = 0, Q = 0.7 })
	self.low = cbFilter({ type = "lp", f = 5, gain = 0, Q = 1.0 })

	self.pre = cbFilter({ type = "tilt", f = 100, gain = 3, Q = 0.4 })
	self.post = cbFilter({ type = "tilt", f = 100, gain = -3, Q = 0.4 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i] * a

		local w = math.max(0, s)

		w = self.low.process(w)
		s = self.pre.process(s)

		local out = tube(s - w + 0.5)

		out = self.high.process(out) * b / a
		out = self.post.process(out)

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
		max = 36,
		changed = function(val)
			a = math.pow(10, val / 20)
		end,
	},
	{
		name = "output",
		min = 0,
		max = 36,
		changed = function(val)
			b = math.pow(10, val / 20)
		end,
	},
})
