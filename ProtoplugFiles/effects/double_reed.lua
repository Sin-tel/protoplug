require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local a = 0
local b = 0
local c = 0

stereoFx.init()
function stereoFx.Channel:init()
	self.s = 0

	self.high = cbFilter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
	self.low = cbFilter({ type = "lp", f = 1000, gain = 0, Q = 1.3 })
end

local function reed(x)
	x = math.max(x, 0)
	return 2.6 * a * x * math.exp(-a * x)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		-- self.s = x

		local x_in = samples[i] + c

		local x = reed(x_in - b * self.s)
		--self.s = self.s + (x - self.s) * 0.13

		self.s = self.low.process(x)

		--samples[i] = self.high.process(-x)
		--samples[i] = 0.2*self.s - x_in + c
		samples[i] = x
	end
end

params = plugin.manageParams({
	{
		name = "a",
		min = 0,
		max = 20,
		changed = function(val)
			a = val
		end,
	},
	{
		name = "b",
		min = 0,
		max = 2,
		changed = function(val)
			b = val
		end,
	},
	{
		name = "c",
		min = 0,
		max = 1,
		changed = function(val)
			c = val
		end,
	},
})
