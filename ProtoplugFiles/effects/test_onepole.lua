require("include/protoplug")
local OnePole = require("include/dsp/onepole")

local f = 2000
local gain = 6
local t = "hs"

stereoFx.init()
function stereoFx.Channel:init()
	self.filter = OnePole({ type = t, f = f, gain = gain })
end

function stereoFx.Channel:processBlock(samples, smax)
	self.filter.update({ type = t, f = f, gain = gain })
	for i = 0, smax do
		local s = samples[i]

		samples[i] = self.filter.process(s)
	end
end

params = plugin.manageParams({
	{
		name = "f",
		min = 20,
		max = 20000,
		changed = function(val)
			f = val
		end,
	},

	{
		name = "gain",
		min = -12,
		max = 12,
		changed = function(val)
			gain = val
		end,
	},

	{
		name = "type",
		type = "list",
		values = { "hs", "ls" },
		changed = function(val)
			t = val
		end,
	},
})
