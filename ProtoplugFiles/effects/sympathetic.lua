--[[
symathetic strings of a piano soundboard
can be used as a sort of reverb

]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/delay_line")

local kap = 0.625

local max_num = 70
local l = max_num
local len = 20
local feedback = 0
local coupling = 0

stereoFx.init()
function stereoFx.Channel:init()
	-- create per-channel fields (filters)
	self.ap = {}
	self.len = {}
	self.filter = {}
	for i = 1, max_num do
		local f = 32.70320 * (2 ^ (i / 12))

		-- 65.40639*(2^(i/12))
		-- 32.70320*(2^(i/12))

		local ll = (44100 / f)

		print(i, ll)

		self.ap[i] = Line(math.floor(ll + 5))

		self.filter[i] = 0

		self.len[i] = ll
	end

	self.last = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local input = samples[i]

		local s = input

		local tot = 0

		for i = 1, l do
			local d = self.ap[i].goBack(self.len[i])

			-- one pole lowpass
			local v = self.filter[i] + (d - self.filter[i]) * kap

			self.filter[i] = v

			tot = tot + d
		end

		tot = tot / l

		local f1 = feedback
		local f2 = coupling

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
	{
		name = "coupling",
		min = 0,
		max = 1,
		changed = function(val)
			coupling = val
		end,
	},
})
