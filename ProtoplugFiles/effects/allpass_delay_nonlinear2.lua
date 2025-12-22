--[[
nonlinear allpass

]]
require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/fdelay_line")

local a = 0
local g = 0

stereoFx.init()
function stereoFx.Channel:init()
	self.delay_a = Line(2000)
	self.delay_b = Line(2000)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local input = samples[i]

		local d1 = self.delay_a.goBack(400)

		local theta = a + g * d1

		local c = math.cos(theta)
		local s = math.sin(theta)

		local u = c * input - s * d1
		local y = s * input + c * d1

		self.delay_a.push(u)

		samples[i] = y
	end
end

params = plugin.manageParams({
	{
		name = "offset",
		min = 0,
		max = 1,
		changed = function(val)
			a = val * 2 * math.pi
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
