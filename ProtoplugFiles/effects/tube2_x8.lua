require("include/protoplug")
local Upsampler11 = require("include/dsp/upsampler_11")
local Upsampler19 = require("include/dsp/upsampler_19")
local Upsampler31 = require("include/dsp/upsampler_31")
local Downsampler19 = require("include/dsp/downsampler_19")
local Downsampler31 = require("include/dsp/downsampler_31")
local Downsampler59 = require("include/dsp/downsampler_59")
local cbFilter = require("include/dsp/cookbook_svf")

Delayline = require("include/dsp/fdelay_line")

local samplerate = 44100

local a = 0
local b = 0
local balance = 1
local c = 0
local bias = 0.4

stereoFx.init()

function softclip(x)
	s = math.max(math.min(x, 3), -3)
	return s * (27 + s * s) / (27 + 9 * s * s)
end

-- everything is per stereo channel
function stereoFx.Channel:init()
	self.phase = 0
	self.upsampler = Upsampler31()
	self.upsampler2 = Upsampler19()
	self.upsampler3 = Upsampler11()
	self.downsampler = Downsampler59()
	self.downsampler2 = Downsampler31()
	self.downsampler3 = Downsampler19()

	self.dry_delay = Delayline(32)

	self.high = cbFilter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
end

function stereoFx.Channel:tick(u)
	u = u - bias
	local s = math.max(u, 0)
	local z = u + s ^ 4

	return softclip(z)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		self.dry_delay.push(s)

		-- oversampling adds 20 samples of delay
		local dry = self.dry_delay.goBack_int(20)

		s = s * a

		local u1, u2 = self.upsampler.tick(s)

		local t1, t2 = self.upsampler2.tick(u1)
		local t3, t4 = self.upsampler2.tick(u2)

		local s1, s2 = self.upsampler3.tick(t1)
		local s3, s4 = self.upsampler3.tick(t2)
		local s5, s6 = self.upsampler3.tick(t3)
		local s7, s8 = self.upsampler3.tick(t4)

		s1 = self:tick(s1)
		s2 = self:tick(s2)
		s3 = self:tick(s3)
		s4 = self:tick(s4)
		s5 = self:tick(s5)
		s6 = self:tick(s6)
		s7 = self:tick(s7)
		s8 = self:tick(s8)

		local out = self.downsampler3.tick(
			self.downsampler2.tick(self.downsampler.tick(s1, s2), self.downsampler.tick(s3, s4)),
			self.downsampler2.tick(self.downsampler.tick(s5, s6), self.downsampler.tick(s7, s8))
		)

		out = out * b / a
		out = self.high.process(out)

		samples[i] = (1.0 - balance) * dry + balance * out
	end
end

params = plugin.manageParams({
	{
		name = "dry/wet",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "drive",
		min = -12,
		max = 36,
		default = 0,
		changed = function(val)
			a = math.pow(10, val / 20)
		end,
	},
	{
		name = "bias",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			bias = val * 0.4
		end,
	},
	{
		name = "output",
		min = 0,
		max = 12,
		default = 0,
		changed = function(val)
			b = math.pow(10, val / 20)
		end,
	},
})

params.resetToDefaults()
