require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")
local Hilbert = require("include/dsp/hilbert")

local Line = require("include/dsp/fdelay_line")

local TWO_PI = 2 * math.pi

local maxLength = 1000

local balance = 0
local time = 1
local feedback = 0
local freq = 0

local function dist(x)
	return math.tanh(x)
end
local lpfilters = {}

stereoFx.init()
function stereoFx.Channel:init(left)
	self.hilbert = Hilbert.new()
	self.left = left

	self.offset = 0
	if left then
		self.offset = 0.25 * TWO_PI
	end

	self.accum = 0

	self.delayline = Line(maxLength)

	self.time = 100
	self.time_ = 100

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

		r, c = self.hilbert.process(inp + d * feedback)
		self.accum = self.accum + freq
		self.accum = self.accum % 1
		local phase = TWO_PI * self.accum + self.offset

		local s = r * math.sin(phase) + c * math.cos(phase)

		--s = self.lp.process(s)
		s = dist(s)
		s = self.high.process(s)

		self.delayline.push(s)

		samples[i] = inp * (1.0 - balance) + d * balance
	end
end

params = plugin.manageParams({
	{
		name = "Dry/Wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = 0.5 * val
		end,
	},
	{
		name = "time",
		min = 0.000,
		max = 0.001,
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
})

--params.resetToDefaults()
