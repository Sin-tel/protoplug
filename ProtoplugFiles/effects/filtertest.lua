require("include/protoplug")
local Filter = require("include/dsp/cookbook filters")
local Filter2 = require("include/dsp/cookbook_svf")

local gain = 0

local freq = 153.0
local res = 0.707

local filters = {}

local db_to_exp = math.log(10) / 20

stereoFx.init()
function stereoFx.Channel:init()
	self.filter = Filter({ type = "lp", f = freq, gain = gain, Q = res })
	self.filter2 = Filter2({ type = "lp", f = freq, gain = gain, Q = res })

	table.insert(filters, self.filter)
	table.insert(filters, self.filter2)
end

local function updateFilters()
	for i, v in ipairs(filters) do
		v.update({ f = freq, gain = gain, Q = res })
	end
	if plugin.isSampleRateKnown() then
		local v1 = filters[1]
		local v2 = filters[2]
		local k1 = v1.phaseDelay(1000.0)
		local k2 = v2.phaseDelay(1000.0)
		print(k1, k2)
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]

		-- local out = self.filter.process(filtergain * inp) / filtergain
		local out = self.filter.process(inp)

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
