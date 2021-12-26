--[[
Feedback compressor
1 sample delay feedback loop
]]
require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"

local a = 50.0
local b = 0.5
local c = 1

local expFactor = -1000.0 / 44100

local drywet = 0.0

-- ms to tau
local function timeConstant(x)
    return 1.0 - math.exp(expFactor / x)
end

local attack  = timeConstant(20)
local release =  timeConstant(80)


stereoFx.init ()
function stereoFx.Channel:init ()
	self.gain_p = 0
	--self.high = cbFilter {type = "hp"; f = 50; gain = 0; Q = 0.7}
end

function stereoFx.Channel:processBlock (samples, smax)
	for i = 0, smax do
	    local inp = samples[i]
	    local peak = math.abs(inp*b)*self.gain_p
	    
	    local gain = 0.5 - 0.5*math.tanh(a*(peak-1))
	    
	    if gain < self.gain_p then
	        self.gain_p = self.gain_p - (self.gain_p - gain)*attack
	    else
	        self.gain_p = self.gain_p - (self.gain_p - gain)*release
	    end
	    
	    local g = self.gain_p
	    

		--samples[i] = g
		
		samples[i] = math.tanh(inp*g*c)*drywet + samples[i]*(1.0-drywet)
	end
end

params = plugin.manageParams {
    {
		name = "Dry Wet";
		min = 0;
		max = 1;
		default = 1;
		changed = function (val) drywet = val end;
	};
	{
		name = "Feedback";
		min = 0;
		max = 10;
		default = 3;
		changed = function (val) a = math.exp(val/3.0) end;
	};
	{
		name = "Threshold";
		min = -30;
		max = 0;
		default = -12;
		changed = function (val) b = 10 ^ (-val/20.0) end;
	};
		{
		name = "Attack";
		min = 1;
		max = 200;
		default = 25;
		changed = function (val) attack = timeConstant(val) end;
	};
		{
		name = "Release";
		min = 1;
		max = 400;
		default = 200;
		changed = function (val) release = timeConstant(val) end;
	};
	{
		name = "MakeUp";
		min = 0;
		max = 24;
		default = 0;
		changed = function (val) c = 10 ^ (val/20.0) end;
	};
}

params.resetToDefaults()