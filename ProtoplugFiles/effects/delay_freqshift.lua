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

local function clip(x)
	-- local s = math.min(math.max(x, -5 / 4), 5 / 4)
	-- return s - (256. / 3125.) * s ^ 5
	-- return math.tanh(x)

	-- local s = math.min(math.max(x, -3.0), 3.0)
	-- return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)

	local s = math.min(math.max(x, -1.5), 1.5)
	return s * (1 - (4 / 27) * s * s)
end

local lpfilters = {}

local abs = math.abs

local v0 = 0.05
local l = 0.45

local function diode(x)
	local v = x - v0
	if v < 0 then
		return 0
	elseif v < l then
		return v * v / (2 * l)
	else
		return x - (v0 + l) + l * l / (2 * l)
	end
	-- return x * x
end

local function mul(x, y)
	return diode(abs(x + 0.5 * y)) - diode(abs(x - 0.5 * y))
	-- return 0.5 * (diode(x + 0.5 * y) - diode(x - 0.5 * y))
end

stereoFx.init()
function stereoFx.Channel:init(left)
	self.hilbert = Hilbert.new()
	self.accum = 0

	self.offset = 0
	if left then
		self.offset = 0.25 * TWO_PI
	end

	self.delayline = Line(maxLength)

	self.time = 22050
	self.time_ = 22050

	self.high = Filter({ type = "hp", f = 20, gain = 0, Q = 0.7 })

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

		-- local s = r * math.sin(phase) + c * math.cos(phase)
		local s = mul(r, math.sin(phase)) + mul(c, math.cos(phase))

		s = self.lp.process(s)
		s = clip(s * 2) / 2
		s = self.high.process(s)

		-- s = s * (1 + 0.002 * (math.random() - 0.5))
		s = s + 0.0002 * (math.random() - 0.5)

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
		min = 0,
		max = 1,
		changed = function(val)
			time = math.exp(6 * (val - 1)) * 44100
		end,
	},
	{
		name = "Feedback",
		max = 1.0,
		changed = function(val)
			feedback = 0.8 * val
		end,
	},
	{
		name = "freq",
		min = -1,
		max = 1,
		default = 0,
		changed = function(val)
			local f = 1000 * val * val * val
			freq = f / 44100
		end,
	},
	{
		name = "Lowpass",
		min = 0,
		max = 1,
		changed = function(val)
			updateFilters(lpfilters, { f = 22000 * math.exp(5 * (val - 1)) })
		end,
	},
})

--params.resetToDefaults()
