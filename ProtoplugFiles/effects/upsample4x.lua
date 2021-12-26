require "include/protoplug"
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
	self.downsampler = Downsampler11()
	self.downsampler2 = Downsampler31()
end

function stereoFx.Channel:tick(u)
	return math.max(-1,math.min(1,u))
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0,smax do
	

	    local s = samples[i]
	    
	    local u1, u2 = self.upsampler.tick(s)
	    local t1, t2 = self.upsampler2.tick(u1)
	    local t3, t4 = self.upsampler2.tick(u2)
	    t1 = self:tick(t1)
	    t2 = self:tick(t2)
	    t3 = self:tick(t3)
	    t4 = self:tick(t4)
	    
	    local out = self.downsampler2.tick(self.downsampler.tick(t1, t2), self.downsampler.tick(t3, t4))
	    
	    --local out = self:tick(s)
	        
	    samples[i] = out
	end
end

params = plugin.manageParams {
	{
		name = "Freq";
		min = 1;
		max = 22000;
		changed = function(val) f = 2*math.pi*val/samplerate end;
	};
}
