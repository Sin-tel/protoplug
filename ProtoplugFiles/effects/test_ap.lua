require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")
--local Filter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/fdelay_line")
local gain = 0

local freq = 440
local res = 0.7

local bfreq = 440

local filters = {}

local db_to_exp = math.log(10) / 20

stereoFx.init()
function stereoFx.Channel:init()
	self.filter = Filter({ type = "ap", f = freq, gain = gain, Q = res })
	self.delay = Line(1024)

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

		local d = self.delay.goBack(44100 / bfreq)

		local s = inp + d * 0.9

		s = self.filter.process(s)

		self.delay.push(s)

		samples[i] = s
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
			res = 0.1 * math.exp(val)
			print(res)
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
		name = "base freq",
		min = 0,
		max = 1,
		changed = function(val)
			bfreq = 20 * math.exp(math.log(1000) * val)
			print(bfreq)
		end,
	},
})
