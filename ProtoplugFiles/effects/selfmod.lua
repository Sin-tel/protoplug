--[[
audio signal that modulates itself
terrible effect to be honest
]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
FLine = require("include/dsp/fdelay_line")

local balance = 0.5

local lp2filters = {}
local filtergain = 1

local lfoFreq = 2 * math.pi * 1 / 44100
local lfoMod = 1.0

local noise = 0.2

local selfmod = 0

local even = 1 / 8
local odd = 1 / 18

local function dist(x)
	if x > 1 then
		return 1 - odd
	elseif x < -1 then
		return -1 + odd
	else
		return x - even * x * x - odd * x * x * x + even
	end
end

stereoFx.init()
function stereoFx.Channel:init()
	-- create per-channel fields (filters)
	self.delayinterp = FLine(32)

	self.high = cbFilter({ type = "hp", f = 1, gain = 0, Q = 0.7 })

	self.lp2 = cbFilter({
		type = "lp",
		f = 12000,
		gain = 0,
		Q = 1.0,
	})
	table.insert(lp2filters, self.lp2)

	self.lfoPhase = 0.0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		self.lfoPhase = self.lfoPhase + lfoFreq

		local input = samples[i]

		local signal = input
		signal = dist(signal)
		signal = self.high.process(signal)
		--signal = self.lp2.process(signal)

		self.delayinterp.push(signal)

		local mod = 1 * (math.random() - 0.5) * jitter + 2 * selfmod * signal

		mod = self.lp2.process(mod) * filtergain

		mod = mod + 10 * math.sin(self.lfoPhase) * lfoMod

		if mod >= 14.0 then
			mod = 14.0
		elseif mod <= -14.0 then
			mod = -14.0
		end

		local interp = self.delayinterp.goBack(16.0 + mod)

		local dry = self.delayinterp.goBack(16.0)

		samples[i] = dry * (1.0 - balance) + interp * balance
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
		name = "LFO Spd",
		--type = "int";
		min = 0.5,
		max = 10,
		changed = function(val)
			lfoFreq = 2 * math.pi * val / 44100
		end,
	},
	{
		name = "LFO Mod",
		--type = "int";
		min = 0,
		max = 1,
		changed = function(val)
			lfoMod = val
		end,
	},
	{
		name = "Noise",
		--type = "int";
		min = 0,
		max = 1,
		changed = function(val)
			jitter = val
		end,
	},
	{
		name = "Self",
		--type = "int";
		min = 0,
		max = 1,
		changed = function(val)
			selfmod = val
		end,
	},
	{
		name = "Cutoff",
		min = 0,
		max = 10,
		changed = function(val)
			updateFilters(lp2filters, { f = 22000 * math.exp(val - 10) })
			filtergain = 1 / math.exp(val - 10)
		end,
	},
	{
		name = "Res",
		min = 0.5,
		max = 10,
		changed = function(val)
			updateFilters(lp2filters, { Q = val })
		end,
	},
})
