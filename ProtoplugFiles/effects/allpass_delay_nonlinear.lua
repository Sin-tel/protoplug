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

		local d1 = self.delay_a.goBack(400) * 0.99
		local d2 = self.delay_b.goBack(321) * 0.99

		d1 = d1 + input
		d2 = d2 + input

		local p = math.sqrt(d1 * d1 + d2 * d2)
		local theta = a + g * p

		local c = math.cos(theta)
		local s = math.sin(theta)

		local x1 = c * d1 - s * d2
		local x2 = s * d1 + c * d2

		self.delay_a.push(x1)
		self.delay_b.push(x2)

		samples[i] = x2
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
