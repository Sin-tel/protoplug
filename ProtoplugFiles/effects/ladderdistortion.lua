-- ladder distortion as one the output of some cheap FM chips

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local w

local function dist(x)
	if x < 0.001 then
		return x - w * 0.01
	else
		return x + w * 0.01
	end
end

stereoFx.init()
function stereoFx.Channel:init() end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		samples[i] = dist(s)
	end
end

params = plugin.manageParams({
	{
		name = "amount",
		min = 0,
		max = 1,
		changed = function(val)
			w = val
		end,
	},
})
