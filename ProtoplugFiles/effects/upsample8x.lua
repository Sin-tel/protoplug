require("include/protoplug")
local Upsampler = require("include/dsp/upsampler_11")
local Downsampler11 = require("include/dsp/downsampler_11")
local Downsampler19 = require("include/dsp/downsampler_19")
local Downsampler31 = require("include/dsp/downsampler_31")
local Downsampler59 = require("include/dsp/downsampler_59")

local samplerate = 44100

local f = 1

stereoFx.init()

-- everything is per stereo channel
function stereoFx.Channel:init()
	self.phase = 0
	self.upsampler = Upsampler()
	self.upsampler2 = Upsampler()
	self.upsampler3 = Upsampler()
	self.downsampler = Downsampler11()
	self.downsampler2 = Downsampler11()
	self.downsampler3 = Downsampler31()
end

function stereoFx.Channel:tick(u)
	return math.max(-1, math.min(1, u))
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

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

		--local out = self:tick(s)

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "Freq",
		min = 1,
		max = 22000,
		changed = function(val)
			f = 2 * math.pi * val / samplerate
		end,
	},
})
