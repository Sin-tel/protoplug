require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf2")
--local Filter = require("include/dsp/cookbook filters")

local gain = 0

local freq = 440
local res = 0.7

local filters = {}

local db_to_exp = math.log(10) / 20

local filtergain = 0

stereoFx.init()
function stereoFx.Channel:init()
	self.filter = Filter({ type = "eq", f = freq, gain = gain, Q = res })

	table.insert(filters, self.filter)
end

function updateFilters()
	for i, v in ipairs(filters) do
		v.update({ f = freq, gain = gain, Q = res })
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]

		local out = self.filter.process(filtergain * inp) / filtergain

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "freq",
		min = 0,
		max = 1,
		changed = function(val)
			freq = 20 * math.exp(math.log(1000) * val)
			print(freq)
			updateFilters()
		end,
	},
	{
		name = "resonance",
		min = 0,
		max = 10,
		changed = function(val)
			res = 0.5 * math.exp(val)
			updateFilters()
		end,
	},
	{
		name = "gain",
		min = -18,
		max = 18,
		changed = function(val)
			gain = val
			updateFilters()
		end,
	},
	{
		name = "filtergain",
		min = -3,
		max = 3,
		changed = function(val)
			filtergain = math.exp(val)
		end,
	},
})
