require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

local gain_low = 0

local f1 = 250
local f2 = 220
local f3 = 770
local f4 = 3000
local f5 = 6600

local res = 0.6

local filters1 = {}
local filters2 = {}
local filters3 = {}
local filters4 = {}
local filters5 = {}

local function softclip(x)
	local s = math.min(math.max(x, -3.0), 3.0)
	return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)
end

local function tube(x)
	local s = math.max(x, -0.5)
	local u = s + s * s
	return softclip(u)
end

stereoFx.init()
function stereoFx.Channel:init()
	self.filter1 = Filter({ type = "lp", f = f1, gain = 0, Q = 0.3 })
	self.filter2 = Filter({ type = "eq", f = f2, gain = 0, Q = 0.5 })
	self.filter3 = Filter({ type = "eq", f = f3, gain = 0, Q = 0.6 })
	self.filter4 = Filter({ type = "eq", f = f4, gain = 0, Q = 0.5 })
	self.filter5 = Filter({ type = "hs", f = f5, gain = 0, Q = 0.5 })

	self.hp = Filter({ type = "hp", f = 5, gain = 0, Q = 0.7 })

	table.insert(filters1, self.filter1)
	table.insert(filters2, self.filter2)
	table.insert(filters3, self.filter3)
	table.insert(filters4, self.filter4)
	table.insert(filters5, self.filter5)
end

local function updateFilters(f, g)
	for i, v in ipairs(f) do
		v.update({ gain = g })
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		local s_low = gain_low * self.filter1.process(s)
		s = self.filter2.process(s)
		s = self.filter3.process(s)
		s = self.filter4.process(s)
		s = self.filter5.process(s)

		s = s + s_low

		s = tube(s * 0.25) * 4

		local out = s

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
			gain_low = 10 ^ (val / 20) - 1.0
		end,
	},
	{
		name = "band 2",
		min = -18,
		max = 18,
		changed = function(val)
			updateFilters(filters2, val)
		end,
	},
	{
		name = "band 3",
		min = -18,
		max = 18,
		changed = function(val)
			updateFilters(filters3, val)
		end,
	},
	{
		name = "band 4",
		min = -18,
		max = 18,
		changed = function(val)
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
})
