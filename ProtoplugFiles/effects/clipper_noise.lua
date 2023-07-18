require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local a = 0
local b = 0
local n = 0

function clip(u)
	return math.max(-1, math.min(1, u)) - u
end

stereoFx.init()
function stereoFx.Channel:init()
	self.prev = 0
	self.high = cbFilter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]
		local diff = self.prev - s
		self.prev = s

		local sum = 0
		for i = 1, n do
			--local t = (i - 1 + b * math.random()) / n
			local t = b * math.random()
			local w = s + t * diff
			sum = sum + clip(w * a)
		end

		sum = sum / n + samples[i]

		out = self.high.process(sum) / a

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "amp",
		min = 0,
		max = 36,
		changed = function(val)
			a = math.pow(10, val / 20)
		end,
	},
	{
		name = "b",
		min = 0,
		max = 1,
		changed = function(val)
			b = val
		end,
	},
	{
		name = "n",
		min = 1,
		max = 16,
		type = "int",
		changed = function(val)
			n = val
		end,
	},
})
