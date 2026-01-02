require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")
local Hilbert = require("include/dsp/hilbert")

local Line = require("include/dsp/fdelay_line")

local TWO_PI = 2 * math.pi

local maxLength = 88200

local balance = 0
local time = 1
local feedback = 0
local freq = 0

local function dist(x)
	return math.tanh(x + 0.2)
end
local lpfilters = {}

stereoFx.init()
function stereoFx.Channel:init()
	self.hilbert = Hilbert.new()
	self.accum = 0

	self.delayline = Line(maxLength)

	self.time = 22050
	self.time_ = 22050

	self.high = Filter({ type = "hp", f = 5, gain = 0, Q = 0.7 })

	self.lp = Filter({
		type = "lp",
		f = 12000,
		gain = 0,
		Q = 0.7,
	})
	table.insert(lpfilters, self.lp)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]

		self.time_ = self.time_ + (time - self.time_) * 0.0002

		local d = self.delayline.goBack(self.time_)

		local r, c

		r, c = self.hilbert.process(inp - d * feedback)
		self.accum = self.accum + freq
		self.accum = self.accum % 1
		local phase = TWO_PI * self.accum

		local s = r * math.sin(phase) + c * math.cos(phase)

		s = self.lp.process(s)
		s = dist(s)
		s = self.high.process(s)

		self.delayline.push(s)

		samples[i] = inp * (1.0 - balance) + d * balance
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
		min = 0.002,
		max = 0.6,
		changed = function(val)
			time = val * 44100
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
		name = "freq",
		min = -25,
		max = 25,
		default = 0,
		changed = function(val)
			freq = val / 44100
		end,
	},
	{
		name = "Lowpass",
		min = 0,
		max = 5,
		changed = function(val)
			updateFilters(lpfilters, { f = 22000 * math.exp(val - 5) })
		end,
	},
})

--params.resetToDefaults()
