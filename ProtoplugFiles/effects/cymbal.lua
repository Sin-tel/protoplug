require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/delay_line")

local kap = 0.625

local max_num = 70
local l = max_num
local len = 20
local feedback = 0
local coupling = 1

channels = {}

stereoFx.init()
function stereoFx.Channel:init()
	table.insert(channels, self)
	-- create per-channel fields (filters)
	self.ap = {}
	self.len = {}
	self.filter = {}
	for i = 1, max_num do
		self.ap[i] = Line(2000)

		self.filter[i] = 0

		self.len[i] = math.random() * 1400 + 500
	end

	self.last = 0

	self.prev = 0
end

function randomize()
	for _, v in ipairs(channels) do
		for i = 1, max_num do
			v.len[i] = math.random() * 1800 + 100
		end
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local input = samples[i]

		local s = input

		local tot = 0

		for i = 1, l do
			local d = self.ap[i].goBack(self.len[i] * master_freq - math.abs(self.prev))

			-- one pole lowpass
			local v = self.filter[i] + (d - self.filter[i]) * kap

			self.filter[i] = v

			tot = tot + v
		end

		tot = tot / l

		self.prev = tot

		local f1 = feedback
		local f2 = coupling * 2 * feedback

		for i = 1, l do
			local v = self.filter[i]

			self.ap[i].push(s + v * f1 - tot * f2)
		end

		self.last = s
		local signal = tot

		samples[i] = input * (1.0 - balance) + signal * balance
	end
end

local function updateFilters(filters, args)
	for _, f in pairs(filters) do
		f.update(args)
	end
end

params = plugin.manageParams({
	{
		name = "Dry/Wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "number",
		min = 0,
		max = max_num,
		type = "int",
		changed = function(val)
			l = val
		end,
	},
	{
		name = "filter",
		min = 0,
		max = 1,
		changed = function(val)
			kap = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	{
		name = "feedback",
		min = 0,
		max = 1,
		changed = function(val)
			feedback = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	-- {
	-- 	name = "coupling",
	-- 	min = 0,
	-- 	max = 1,
	-- 	changed = function(val)
	-- 		coupling = val
	-- 	end,
	-- },
	{
		name = "frequency",
		min = 0.1,
		max = 1,
		changed = function(val)
			master_freq = val
		end,
	},
	{
		name = "randomize",
		min = 0,
		max = 1,
		changed = function(val)
			randomize()
		end,
	},
})
