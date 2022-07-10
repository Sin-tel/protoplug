--[[
limiter with hilbert peak estimation
]]

require("include/protoplug")
local hilbert = require("include/dsp/hilbert")

require("include/protoplug")

local expFactor = -1000.0 / 44100

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local release = timeConstant(80)

local filters = {}

stereoFx.init()
function stereoFx.Channel:init()
	self.filter = hilbert()

	self.gain_p = 0

	table.insert(filters, self.filter)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]

		local r, c

		--
		r, c = self.filter.process(inp)

		local peak = math.sqrt(r * r + c * c)
		--local peak = math.abs(r)

		local gain = math.min(1.0, 1.0 / peak)

		if gain < self.gain_p then
			self.gain_p = gain
		else
			self.gain_p = self.gain_p - (self.gain_p - gain) * release
		end

		local g = self.gain_p

		samples[i] = r * g
	end
end

params = plugin.manageParams({
	{
		name = "Release",
		min = 1,
		max = 800,
		default = 20,
		changed = function(val)
			release = timeConstant(val)
		end,
	},
})

params.resetToDefaults()
