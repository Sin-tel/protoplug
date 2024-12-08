--[[
automatically kills the signal if there is a NaN, +/-Inf or other weird things happening

useful when working on systems with feedback so you dont accidentally makes loud noises
]]
require("include/protoplug")

local kill = false

stereoFx.init()
function stereoFx.Channel:init()
	self.s = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = 0
		if not kill then
			s = samples[i]
			if s ~= s then
				kill = true
				print("killed due to NaN")
			end
			if s >= math.huge then
				kill = true
				print("killed due to +Inf")
			end
			if -math.huge >= s then
				kill = true
				print("killed due to +Inf")
			end
			if math.abs(s) > 1.0 then
				kill = true
				print("signal too large: ", s)
			end
		end

		samples[i] = s
	end
end

params = plugin.manageParams({
	{
		name = "reset",
		min = 0,
		max = 1,
		changed = function(val)
			kill = false
		end,
	},
})
