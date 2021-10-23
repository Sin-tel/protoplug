require "include/protoplug"
local Upsampler = require("include/dsp/wavelet_up")
local Downsampler = require("include/dsp/wavelet_down")


local samplerate = 44100

local f = 1

stereoFx.init()

-- everything is per stereo channel
function stereoFx.Channel:init()
	self.phase = 0
	self.upsampler = Upsampler()
	self.downsampler = Downsampler()
	
	self.upsampler2 = Upsampler()
	self.downsampler2 = Downsampler()
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0,smax,4 do
	    local i0, i1 = samples[i], samples[i+1]
	    local i2, i3 = samples[i+2], samples[i+3]

	    local lp0, hp0 = self.downsampler.tick(i0, i1)
	    local lp1, hp1 = self.downsampler.tick(i2, i3)
	    
	    local lp00, hp00 = self.downsampler2.tick(lp0, lp1)
	    
	    local s00, s01 = self.upsampler2.tick(lp00*1, hp00*0)
	    
	    
	    local s0, s1 = self.upsampler.tick(s00, hp0*0)
	    local s2, s3 = self.upsampler.tick(s01, hp1*0)
	    
	    samples[i] = s0
	    samples[i+1] = s1
	    samples[i+2] = s2
	    samples[i+3] = s3
	
	end
end

--[[params = plugin.manageParams {
	{
		name = "Freq";
		min = 1;
		max = 22000;
		changed = function(val) f = 2*math.pi*val/samplerate end;
	};
}]]
