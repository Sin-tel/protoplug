--[[
limiter with hilbert peak estimation
]]

require("include/protoplug")
local Hilbert = require("include/dsp/hilbert")

local TWO_PI = 2 * math.pi

stereoFx.init()
function stereoFx.Channel:init()
	self.hilbert = Hilbert.new()
	self.accum = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]

		local r, c

		r, c = self.hilbert.process(inp)
		self.accum = self.accum + freq
		self.accum = self.accum % 1
		local phase = TWO_PI * self.accum

		local s = r * math.sin(phase) + c * math.cos(phase)

		samples[i] = s
	end
end

params = plugin.manageParams({
	{
		name = "freq",
		min = -100,
		max = 100,
		default = 0,
		changed = function(val)
			freq = val / 44100
		end,
	},
})

params.resetToDefaults()
