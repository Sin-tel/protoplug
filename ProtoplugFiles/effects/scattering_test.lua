-- 2 waveguides with KL scattering junction, unfolded into a linear structure
-- needs only 2 delay lines instead of 4

require("include/protoplug")
local Line = require("include/dsp/fdelay_line")

local master_freq = 1
local feedback = 0

local channels = {}

local len1 = 500
local len2 = 500

local k1_b = 1

local k1 = 0

stereoFx.init()
function stereoFx.Channel:init()
	table.insert(channels, self)

	self.delay1 = Line(500)
	self.delay2 = Line(500)
end

function stereoFx.Channel:processBlock(samples, smax)
	for k = 0, smax do
		local input = samples[k]

		local d1 = self.delay1.goBack(len1 * master_freq)
		local d2 = self.delay2.goBack(len2 * master_freq)

		self.delay1.push(input + feedback * (k1_b * d2 + k1 * d1))
		self.delay2.push(k1_b * d1 - k1 * d2)

		local s = d2

		samples[k] = s
	end
end

params = plugin.manageParams({
	{
		name = "len1",
		min = 10,
		max = 490,
		changed = function(val)
			len1 = val
			len2 = 500 - val
		end,
	},
	{
		name = "k1",
		min = -1,
		max = 1,
		changed = function(val)
			k1 = val
			k1_b = math.sqrt(1 - k1 * k1)
		end,
	},
	{
		name = "feedback",
		min = -1,
		max = 1,
		changed = function(val)
			feedback = val
		end,
	},
	{
		name = "frequency",
		min = 0.05,
		max = 1.0,
		changed = function(val)
			master_freq = val
		end,
	},
})
