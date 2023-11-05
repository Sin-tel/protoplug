-- 3 serial waveguides with KL scattering junctions, unfolded into a linear structure
-- needs only 3 delay lines instead of 6

require("include/protoplug")
local Line = require("include/dsp/fdelay_line")

local master_freq = 1
local feedback = 0

local channels = {}

local len1 = 500
local len2 = 500
local len3 = 500

local k1_b = 1
local k2_b = 1

local k1 = 0
local k2 = 0

stereoFx.init()
function stereoFx.Channel:init()
	table.insert(channels, self)

	self.delay1 = Line(500)
	self.delay2 = Line(500)
	self.delay3 = Line(500)
end

function stereoFx.Channel:processBlock(samples, smax)
	for k = 0, smax do
		local input = samples[k]

		local d1 = self.delay1.goBack(len1 * master_freq)
		local d2 = self.delay2.goBack(len2 * master_freq)
		local d3 = self.delay3.goBack(len3 * master_freq)

		local d4 = (k2 * d2 + k2_b * d3)

		self.delay1.push(input + feedback * (k1_b * d4 + k1 * d1))
		self.delay2.push(k1_b * d1 - k1 * d4)
		self.delay3.push(k2_b * d2 - k2 * d3)

		local s = d3

		samples[k] = s
	end
end

params = plugin.manageParams({
	{
		name = "len1",
		min = 10,
		max = 240,
		changed = function(val)
			len1 = val
			len3 = 500 - len1 - len2
		end,
	},
	{
		name = "len2",
		min = 10,
		max = 240,
		changed = function(val)
			len2 = val
			len3 = 500 - len1 - len2
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
		name = "k2",
		min = -1,
		max = 1,
		changed = function(val)
			k2 = val
			k2_b = math.sqrt(1 - k2 * k2)
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
