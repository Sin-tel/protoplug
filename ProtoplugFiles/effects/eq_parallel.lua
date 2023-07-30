-- parallel "passive" analog-style EQ, with a tube stage

require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf2")

local Filter_linear = require("include/dsp/cookbook_svf")

local gain = 0

local f1 = 100
local f2 = 240
local f3 = 750
local f4 = 3000
local f5 = 6600

local filters1 = {}
local filters2 = {}
local filters3 = {}
local filters4 = {}
local filters5 = {}

local gain1 = 1
local gain2 = 1
local gain3 = 1
local gain4 = 1
local gain5 = 1

local filtergain = 0

function gainf(x)
	return math.pow(10, x / 20) - 1
end

function softclip(x)
	local s = math.min(math.max(x, -3.0), 3.0)
	return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)
end

function tube(x)
	local s = math.max(x, -0.5)
	local s = s + s * s
	return softclip(s)
end

stereoFx.init()
function stereoFx.Channel:init()
	self.filter1 = Filter({ type = "ls", f = f1, gain = 0, Q = 1.8 })
	self.filter2 = Filter({ type = "eq", f = f2, gain = 0, Q = 0.7 })
	self.filter3 = Filter({ type = "eq", f = f3, gain = 0, Q = 0.7 })
	self.filter4 = Filter({ type = "eq", f = f4, gain = 0, Q = 0.7 })
	self.filter5 = Filter({ type = "hs", f = f5, gain = 0, Q = 1.0 })

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

		local s2 = 0
		s2 = s2 + (self.filter1.process(s1) - s1)
		s2 = s2 + (self.filter2.process(s1) - s1)
		s2 = s2 + (self.filter3.process(s1) - s1)
		s2 = s2 + (self.filter4.process(s1) - s1)
		s2 = s2 + (self.filter5.process(s1) - s1)

		-- boost second harmonic generation
		s2 = tube(s2 * 0.25) * 4

		local out = inp + s2 / filtergain

		out = self.hp.process(out)

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "band 1",
		min = -24,
		max = 24,
		changed = function(val)
			updateFilters(filters1, val)
		end,
	},
	{
		name = "band 2",
		min = -24,
		max = 24,
		changed = function(val)
			updateFilters(filters2, val)
		end,
	},
	{
		name = "band 3",
		min = -24,
		max = 24,
		changed = function(val)
			updateFilters(filters3, val)
		end,
	},
	{
		name = "band 4",
		min = -24,
		max = 24,
		changed = function(val)
			updateFilters(filters4, val)
		end,
	},
	{
		name = "band 5",
		min = -24,
		max = 24,
		changed = function(val)
			updateFilters(filters5, val)
		end,
	},
	{
		name = "filtergain",
		min = -36,
		max = 12,
		changed = function(val)
			filtergain = math.pow(10, val / 20)
		end,
	},
})
