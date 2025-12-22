require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")
local Delay = require("include/dsp/fdelay_line")

local gain = -6

local freq = 153.0
local res = 0.707

local filters = {}

local db_to_exp = math.log(10) / 20

local f_delay = 500

local k_f = 1.0

local feedback = 0.7

local len_corr = 0

stereoFx.init()
function stereoFx.Channel:init()
	self.filter = Filter({ type = "ap", f = freq, gain = gain, Q = res })

	self.delay = Delay(1000)

	table.insert(filters, self.filter)
end

local function updateFilters()
	for i, v in ipairs(filters) do
		v.update({ f = freq, gain = gain, Q = res })
	end

	if plugin.isSampleRateKnown() then
		len_corr = -filters[1].phaseDelay(f_delay)
		print(len_corr)
		-- fix phase discontinuity
		if len_corr > 0 then
			len_corr = len_corr - 44100 / f_delay
		end
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s_in = samples[i]

		-- local s = self.delay.goBack_int(120)
		local s = self.delay.goBack(len_corr + 44100 / f_delay)
		-- local s = self.delay.goBack(44100 / f_delay)

		s = self.filter.process(s)
		s = s * feedback + s_in

		self.delay.push(s)

		-- local out = self.filter.process(s_in)
		local out = s

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "freq delay",
		min = 20,
		max = 1000,
		changed = function(val)
			f_delay = val
			freq = f_delay * k_f

			updateFilters()
		end,
	},
	{
		name = "freq filter",
		min = 0,
		max = 1,
		changed = function(val)
			-- freq = 20 * math.exp(math.log(1000) * val)
			-- freq = (val ^ 5) * 44100

			k_f = 1 + 9 * val

			freq = f_delay * k_f
			updateFilters()
		end,
	},
	{
		name = "Q",
		min = 0.2,
		max = 5,
		changed = function(val)
			res = val
			updateFilters()
		end,
	},
	{
		name = "feedback",
		min = 0,
		max = 1,
		changed = function(val)
			feedback = val
		end,
	},
})
