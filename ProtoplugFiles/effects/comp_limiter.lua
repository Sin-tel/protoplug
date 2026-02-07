--[[
Quick and dirty limiter
]]

require("include/protoplug")

local expFactor = -1000.0 / 44100

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local release = timeConstant(80)

stereoFx.init()
function stereoFx.Channel:init()
	self.gain_p = 1
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]
		local peak = math.abs(inp)

		local gain = math.min(1.0, 1.0 / peak)

		if gain < self.gain_p then
			self.gain_p = gain
		else
			self.gain_p = self.gain_p - (self.gain_p - gain) * release
		end

		local g = self.gain_p

		samples[i] = inp * g
	end
end

params = plugin.manageParams({
	{
		name = "Release",
		min = 1,
		max = 800,
		default = 200,
		changed = function(val)
			release = timeConstant(val)
		end,
	},
})

params.resetToDefaults()
