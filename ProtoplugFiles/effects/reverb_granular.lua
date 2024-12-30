require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
local cbFilter = require("include/dsp/cookbook filters")

local maxLength = 3 * 44100
local fade_speed = 2.0
local grain_len = 0.2
local random_len = 0.5

local balance = 0.5
local size = 1
local size_ = 1
local feedback = 0
local t_60 = 1.0

local l1 = 1712
local l2 = 2349
local l3 = 5227
local l4 = 4547

local k_ap = 0.625

local ap1 = Line(2000)
local ap2 = Line(2000)
local ap3 = Line(2000)
local ap4 = Line(2000)

local ap1_l = 142
local ap2_l = 107
local ap3_l = 379
local ap4_l = 277

local hp1 = cbFilter({
	type = "hp",
	f = 50,
	gain = 0,
	Q = 0.7,
})

local hp2 = cbFilter({
	type = "hp",
	f = 50,
	gain = 0,
	Q = 0.7,
})

local shelf1 = cbFilter({
	type = "hs",
	f = 8000,
	gain = -3,
	Q = 0.7,
})

local shelf2 = cbFilter({
	type = "hs",
	f = 8000,
	gain = -3,
	Q = 0.7,
})

local function allpass(ap, s, l)
	local d = ap.goBack_int(l)
	local v = s - k_ap * d
	ap.push(v)
	return k_ap * v + d
end

local function crossfade(x)
	local x2 = 1 - x
	local a = x * x2
	local b = a * (1 + 0.5 * a)
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

local GrainDelay = {}
GrainDelay.__index = GrainDelay

function GrainDelay.new()
	local self = setmetatable({}, GrainDelay)

	self.delayline = Line(maxLength)
	self.ptr1 = 0
	self.ptr2 = 0
	self.a = 1.0
	self.even = false
	self.timer = math.random()
	self.grain_len = 0.2

	return self
end

local delay1 = GrainDelay.new()
local delay2 = GrainDelay.new()
local delay3 = GrainDelay.new()
local delay4 = GrainDelay.new()

function GrainDelay:tick(l)
	self.timer = self.timer + 1 / 44100

	local fs = fade_speed / (44100 * self.grain_len)

	if self.even then
		self.a = math.min(1.0, self.a + fs)
	else
		self.a = math.max(0.0, self.a - fs)
	end

	if self.timer > self.grain_len then
		l = l * (1 + random_len * (math.random() - 0.5))

		if self.even then
			self.ptr2 = l
			self.even = false
		else
			self.ptr1 = l
			self.even = true
		end
		self.timer = 0.0
		self.grain_len = grain_len * (1.0 + 0.2 * (math.random() - 0.5))
	end

	local a1, a2 = crossfade(self.a)
	return a1 * self.delayline.goBack(self.ptr1) + a2 * self.delayline.goBack(self.ptr2)
end

function GrainDelay:push(s)
	self.delayline.push(s)
end

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local input_l = samples[0][i]
		local input_r = samples[1][i]

		size_ = size_ - (size_ - size) * 0.001

		local sl = input_l
		local sr = input_r

		local d1 = delay1:tick(l1 * size)
		local d2 = delay2:tick(l2 * size)
		local d3 = delay3:tick(l3 * size)
		local d4 = delay4:tick(l4 * size)

		d1 = softclip(d1)
		d2 = softclip(d2)
		d3 = softclip(d3)
		d4 = softclip(d4)

		-- hadamard mixing
		local s1 = (sl + (d1 + d2 + d3 + d4) * feedback * 0.5)
		local s2 = (sr + (d1 - d2 + d3 - d4) * feedback * 0.5)
		local s3 = (sl + (d1 + d2 - d3 - d4) * feedback * 0.5)
		local s4 = (sr + (d1 - d2 - d3 + d4) * feedback * 0.5)

		s1 = allpass(ap1, s1, ap1_l)
		s2 = allpass(ap2, s2, ap2_l)
		s3 = allpass(ap3, s3, ap3_l)
		s4 = allpass(ap4, s4, ap4_l)

		s1 = hp1.process(s1)
		s2 = hp2.process(s2)
		s3 = shelf1.process(s3)
		s4 = shelf2.process(s4)

		delay1:push(s1)
		delay2:push(s2)
		delay3:push(s3)
		delay4:push(s4)

		sl = 0.5 * (d1 + d3)
		sr = 0.5 * (d2 + d4)

		samples[0][i] = input_l * (1.0 - balance) + sl * balance
		samples[1][i] = input_r * (1.0 - balance) + sr * balance
	end
end

local function setFeedback(t)
	if t then
		t_60 = t
	end
	if t_60 > 15 then
		feedback = 1.0
	else
		feedback = 10 ^ (-(60 * 4000 * size) / (t_60 * 44100 * 20))
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
		name = "Size",
		min = 0.01,
		max = 1.50,
		changed = function(val)
			size = val
			setFeedback()
		end,
	},
	{
		name = "Decay Time",
		min = 0.0,
		max = 1.0,
		changed = function(val)
			setFeedback(2 ^ (8 * val - 4))
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
})
