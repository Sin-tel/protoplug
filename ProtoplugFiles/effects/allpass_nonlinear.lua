--[[
nonlinear allpass

]]
require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local a = 0
local g = 0

stereoFx.init()
function stereoFx.Channel:init()
	self.s = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local input = samples[i]

		local c = math.cos(a + g * input)
		local s = math.sin(a + g * input)

		local u = c * input - s * self.s
		local y = s * input + c * self.s

		self.s = u

		samples[i] = y
	end
end

params = plugin.manageParams({
	{
		name = "offset",
		min = 0,
		max = 6,
		changed = function(val)
			a = val
		end,
	},
	{
		name = "gain",
		min = 0,
		max = 1,
		changed = function(val)
			g = val
		end,
	},
})
