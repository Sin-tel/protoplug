require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf2")

local Filter_linear = require("include/dsp/cookbook_svf")
--local Filter = require("include/dsp/cookbook filters")

local gain = 0

local f1 = 100
local f2 = 240
local f3 = 750
local f4 = 3000
local f5 = 6600

local res = 0.7

local filters1 = {}
local filters2 = {}
local filters3 = {}
local filters4 = {}
local filters5 = {}

local db_to_exp = math.log(10) / 20

local filtergain = 0

stereoFx.init()
function stereoFx.Channel:init()
	self.filter1 = Filter({ type = "ls", f = f1, gain = 0, Q = res })
	self.filter2 = Filter({ type = "eq", f = f2, gain = 0, Q = res })
	self.filter3 = Filter({ type = "eq", f = f3, gain = 0, Q = res })
	self.filter4 = Filter({ type = "eq", f = f4, gain = 0, Q = res })
	self.filter5 = Filter({ type = "hs", f = f5, gain = 0, Q = res })

	self.hp = Filter_linear({ type = "hp", f = 10, gain = 0, Q = 0.7 })

	table.insert(filters1, self.filter1)
	table.insert(filters2, self.filter2)
	table.insert(filters3, self.filter3)
	table.insert(filters4, self.filter4)
	table.insert(filters5, self.filter5)
end

function updateFilters(f, g)
	for i, v in ipairs(f) do
		v.update({ gain = g })
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]

		local s1 = inp * filtergain

		s1 = self.filter5.process(s1)
		s1 = self.filter4.process(s1)
		s1 = self.filter3.process(s1)
		s1 = self.filter2.process(s1)
		s1 = self.filter1.process(s1)

		s1 = math.tanh(s1)

		local out = s1 / filtergain

		out = self.hp.process(out)

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "band 1",
		min = -18,
		max = 18,
		changed = function(val)
			--gain = val
			updateFilters(filters1, val)
		end,
	},
	{
		name = "band 2",
		min = -18,
		max = 18,
		changed = function(val)
			--gain = val
			updateFilters(filters2, val)
		end,
	},
	{
		name = "band 3",
		min = -18,
		max = 18,
		changed = function(val)
			--gain = val
			updateFilters(filters3, val)
		end,
	},
	{
		name = "band 4",
		min = -18,
		max = 18,
		changed = function(val)
			--gain = val
			updateFilters(filters4, val)
		end,
	},
	{
		name = "band 5",
		min = -18,
		max = 18,
		changed = function(val)
			updateFilters(filters5, val)
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
