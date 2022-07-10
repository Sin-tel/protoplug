--[[
even and odd polynomial distortion

--]]
require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local even
local odd

local function dist(x)
	if x > 1 then
		return 1 - odd
	elseif x < -1 then
		return -1 + odd
	else
		return x - even * x * x - odd * x * x * x + even
	end
end

stereoFx.init()
function stereoFx.Channel:init()
	-- create per-channel fields (filters)

	self.high = cbFilter({ type = "hp", f = 20, gain = 0, Q = 0.3 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = dist(samples[i])
		samples[i] = self.high.process(s)
	end
end

params = plugin.manageParams({
	{
		name = "even",
		min = 0,
		max = 1,
		changed = function(val)
			even = val
		end,
	},
	{
		name = "odd",
		min = 0,
		max = 1,
		changed = function(val)
			odd = val
		end,
	},
})
