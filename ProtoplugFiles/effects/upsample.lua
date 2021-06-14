require "include/protoplug"
local Upsampler = require("include/dsp/upsampler2")
local Downsampler = require("include/dsp/downsampler")


local samplerate = 44100

local f = 1

stereoFx.init()

-- everything is per stereo channel
function stereoFx.Channel:init()
	self.phase = 0
	self.upsampler = Upsampler()
	self.downsampler = Downsampler()
end

function stereoFx.Channel:tick(u)
	return math.tanh(2*u)*0.5
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0,smax do

	    self.phase = self.phase + f
	    local s = math.sin(self.phase)
	    
	    
	    local u1, u2 = self.upsampler.tick(s)
	    u1 = self:tick(u1)
	    u2 = self:tick(u2)
	    local out = self.downsampler.tick(u1, u2)
	    
	   -- local out = self:tick(s)
	        
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
