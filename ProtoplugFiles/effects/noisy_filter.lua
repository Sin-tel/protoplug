require("include/protoplug")

local c = 0
local a = 0
local b = 0

stereoFx.init()
function stereoFx.Channel:init()
	self.s = 0

	self.s2 = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local x = samples[i] * 1.2

		self.s2 = self.s2 + a * (math.random() - self.s2)

		local r = self.s2 * b * c + (1 - c)
		self.s = self.s + r * (x - self.s)

		samples[i] = self.s
	end
end

params = plugin.manageParams({
	{
		name = "noise",
		min = 0,
		max = 6,
		changed = function(val)
			c = 1.0 - math.exp(-val)
			print(c)
		end,
	},

	{
		name = "low",
		min = 0,
		max = 6,
		changed = function(val)
			b = math.exp(-val)
			print(b)
		end,
	},

	{
		name = "low noise",
		min = 0,
		max = 6,
		changed = function(val)
			a = math.exp(-val)
			print(a)
		end,
	},
})
