--[[
bucket brigade delay
the bbd itself runs at a variable (noninteger) samplerate 
with a simple lowpass to do a bit of antialiasing
]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
FLine = require("include/dsp/fdelay_line")

local maxLength = 4102
local read = 4096

local feedback = 0
local balance = 0.5

local lpfilters = {}
local lp2filters = {}

local lfoFreq = 2 * math.pi * 1 / 44100
local lfoMod = 1.0

local jitter = 0.2

local freq = 1

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
	self.clock = 0
	self.delayline = FLine(maxLength)
	self.delayinterp = FLine(16)

	self.high = cbFilter({ type = "hp", f = 1, gain = 0, Q = 0.7 })

	self.lp = cbFilter({
		type = "lp",
		f = 12000,
		gain = 0,
		Q = 0.7,
	})
	table.insert(lpfilters, self.lp)
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

		local d = self.delayline.goBack(read - self.clock)

		d = d + 0.003 * (math.random() - 0.5)

		d = self.lp.process(d)

		local signal = input + d * feedback
		signal = dist(signal)
		signal = self.high.process(signal)
		signal = self.lp2.process(signal)

		self.delayinterp.push(signal)

		self.clock = self.clock
			+ freq
			+ 0.02 * (math.random() - 0.5) * jitter
			+ 0.05 * math.sin(self.lfoPhase) * lfoMod * freq
		if self.clock >= 1.0 then
			self.clock = self.clock % 1
			local interp = self.delayinterp.goBack(5.0 + self.clock)
			self.delayline.push(interp)
		end

		samples[i] = input * (1.0 - balance) + d * balance
	end
end

local function updateFilters(filters, args)
	for _, f in pairs(filters) do
		f.update(args)
	end
end

params = plugin.manageParams({
	{
		name = "Feedback",
		max = 1.2,
		changed = function(val)
			feedback = val
		end,
	},
	{
		name = "Dry/Wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "Lowpass",
		min = 0,
		max = 5,
		changed = function(val)
			updateFilters(lp2filters, { f = 22000 * math.exp(val - 5) })
		end,
	},
	{
		name = "Freq",
		--type = "int";
		min = 1,
		max = 20,
		changed = function(val)
			freq = 1.0 / val
			updateFilters(lpfilters, { f = 22000 / val })
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
		name = "clock jitter",
		--type = "int";
		min = 0,
		max = 1,
		changed = function(val)
			jitter = val
		end,
	},
})
