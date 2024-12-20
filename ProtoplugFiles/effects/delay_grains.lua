require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
local cbFilter = require("include/dsp/cookbook filters")

local maxLength = 3 * 44100
local fade_speed = 2.0
local grain_len = 0.2
local random_len = 0.5

local balance = 0.5
local length = 1
local feedback = 0
local gain = 1

local lpfilters = {}
local hpfilters = {}

local function crossfade(x)
	local x2 = 1 - x
	local a = x * x2
	local b = a * (1 + 1.4186 * a)
	local c = (b + x)
	local d = (b + x2)
	return c * c, d * d
	-- return x, (1.0 - x)
end

local function softclip(x)
	if x <= -1 then
		return -2.0 / 3.0
	elseif x >= 1 then
		return 2.0 / 3.0
	else
		return x - (x * x * x) / 3.0
	end
end

stereoFx.init()

function stereoFx.Channel:init()
	self.delayline = Line(maxLength)
	self.ptr1 = 0
	self.ptr2 = 0
	self.a = 1.0

	self.even = false

	self.timer = 0

	self.lp = cbFilter({
		type = "lp",
		f = 12000,
		gain = 0,
		Q = 0.7,
	})
	table.insert(lpfilters, self.lp)
	self.hp = cbFilter({
		type = "hp",
		f = 350,
		gain = 0,
		Q = 0.7,
	})
	table.insert(hpfilters, self.hp)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		self.timer = self.timer + 1 / 44100

		local fs = fade_speed / (44100 * grain_len)

		if self.even then
			self.a = math.min(1.0, self.a + fs)
		else
			self.a = math.max(0.0, self.a - fs)
		end

		if self.timer > grain_len then
			local l = length * 44100
			l = l * (1 + random_len * (math.random() - 0.5))

			if self.even then
				self.ptr2 = l
				self.even = false
			else
				self.ptr1 = l
				self.even = true
			end
			self.timer = 0
		end

		local s = samples[i]

		local a1, a2 = crossfade(self.a)
		local d = a1 * self.delayline.goBack(self.ptr1) + a2 * self.delayline.goBack(self.ptr2)

		d = self.lp.process(d)
		d = self.hp.process(d)
		d = softclip(d * gain) / gain

		local signal = s + d * feedback
		self.delayline.push(signal)
		samples[i] = s * (1.0 - balance) + d * balance
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
		name = "Length",
		max = 2,
		changed = function(val)
			length = val
		end,
	},
	{
		name = "Feedback",
		max = 1.2,
		changed = function(val)
			feedback = val
		end,
	},
	{
		name = "Grain length",
		min = 0.02,
		max = 1.0,
		changed = function(val)
			grain_len = val
		end,
	},
	{
		name = "Grain randomize",
		min = 0.0,
		max = 1.0,
		changed = function(val)
			random_len = val
		end,
	},
	-- {
	-- 	name = "Distort",
	-- 	max = 4,
	-- 	min = 1,
	-- 	changed = function(val)
	-- 		gain = val
	-- 	end,
	-- },

	{
		name = "Highpass",
		min = 0,
		max = 1000,
		changed = function(val)
			updateFilters(hpfilters, { f = val })
		end,
	},
	{
		name = "Lowpass",
		min = 5000,
		max = 22000,
		changed = function(val)
			updateFilters(lpfilters, { f = val })
		end,
	},
})
