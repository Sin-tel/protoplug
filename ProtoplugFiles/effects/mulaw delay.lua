--[[
lofi  delay

]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
FLine = require("include/dsp/fdelay_line")

local maxLength = 88200

local feedback = 0
local balance = 0.5

local lpfilters = {}

local lfoFreq = 2 * math.pi * 1 / 44100
local lfoMod = 1.0

local bdepth
local m

local time = 22050
local off = 1.1

local function sign(x)
	if x > 0 then
		return 1
	else
		return -1
	end
end

stereoFx.init()
function stereoFx.Channel:init()
	-- create per-channel fields (filters)
	self.delayline = FLine(maxLength)

	self.high = cbFilter({ type = "hp", f = 150, gain = 0, Q = 0.7 })

	self.lp = cbFilter({
		type = "lp",
		f = 22000,
		gain = 0,
		Q = 0.7,
	})
	table.insert(lpfilters, self.lp)

	self.lfoPhase = 0.0
	self.time = 22050
	self.time_ = 22050
end

function compand(s)
	local u = sign(s) * math.log(1 + m * math.abs(s)) / math.log(1 + m)

	u = math.floor(bdepth * u) / bdepth

	local c = sign(u) * (math.pow(1 + m, math.abs(u)) - 1) / m
	return math.min(math.max(c, -1), 1)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		self.lfoPhase = self.lfoPhase + lfoFreq

		local input = samples[i]

		self.time_ = self.time_ + (self.time - self.time_) * 0.0002

		local d = self.delayline.goBack(self.time_ + lfoMod * 40 * math.sin(self.lfoPhase))

		local signal = input + d * feedback

		signal = self.high.process(signal)
		signal = compand(signal)
		signal = self.lp.process(signal)

		self.delayline.push(signal)

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
		name = "Dry/Wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "time",

		--type = "int";
		min = 0.002,
		max = 2,
		changed = function(val)
			time = val * 44100
			stereoFx.LChannel.time = time * off
			stereoFx.RChannel.time = time / off
		end,
	},
	{
		name = "stereo offset",

		--type = "int";
		min = -1,
		max = 1,
		changed = function(val)
			off = 2 ^ val
			stereoFx.LChannel.time = time * off
			stereoFx.RChannel.time = time / off
		end,
	},
	{
		name = "Feedback",
		max = 1.02,
		changed = function(val)
			feedback = val
		end,
	},
	{
		name = "bits",
		type = "int",
		min = 4,
		max = 12,
		changed = function(val)
			bdepth = math.pow(2, val - 1)
			m = bdepth * 2 - 1
		end,
	},
	{
		name = "Lowpass",
		min = 0,
		max = 5,
		changed = function(val)
			updateFilters(lpfilters, { f = 22000 * math.exp(val - 5) })
			print(22000 * math.exp(val - 5))
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
})
