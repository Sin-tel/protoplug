--[[
mulaw BEFORE
]]
require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local bdepth
local m

local function sign(x)
	if x > 0 then
		return 1
	else
		return -1
	end
end

stereoFx.init()
function stereoFx.Channel:init()
	-- create per-channel fields (filters)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		local u = sign(s) * math.log(1 + m * math.abs(s)) / math.log(1 + m)

		--local c = sign(u)*(math.pow(1+m,math.abs(u))-1)/m

		samples[i] = u --c
	end
end

params = plugin.manageParams({
	{
		name = "m",
		min = 1,
		max = 20,
		default = 10,
		changed = function(val)
			m = val
		end,
	},
})

params.resetToDefaults()
