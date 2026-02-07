--[[
limiter with hilbert peak estimation
]]

require("include/protoplug")
local Hilbert = require("include/dsp/hilbert")

require("include/protoplug")

local expFactor = -1000.0 / 44100

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local release = timeConstant(80)
local use_hilbert = true

local function clip(x)
	return math.min(math.max(x, -1.0), 1.0)
end

stereoFx.init()
function stereoFx.Channel:init(left)
	self.filter = Hilbert.new()

	self.gain_p = 0

	self.left = left
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		local r, c

		r, c = self.filter.process(s)

		local peak = math.abs(s)
		if use_hilbert then
			peak = math.sqrt(r * r + c * c)
		end

		local gain = math.min(1.0, 1.0 / peak)

		if gain < self.gain_p then
			self.gain_p = gain
		else
			self.gain_p = self.gain_p - (self.gain_p - gain) * release
		end

		-- TODO: delay compensation
		local g = self.gain_p
		local out = g * r
		-- if self.left then
		-- 	out = peak
		-- end

		-- hardclip any peaks we might have missed
		-- out = clip(out)

		samples[i] = out
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

	{
		name = "use hilbert",
		type = "list",
		values = { "off", "on" },
		default = "on",
		changed = function(val)
			use_hilbert = (val == "on")
		end,
	},
})

params.resetToDefaults()
