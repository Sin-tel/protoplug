--[[
Feedback compressor
1 sample delay feedback loop
]]
require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"

local a = 50.0
local b = 0.5
local c = 1

local expFactor = -2.0 * math.pi * 1000.0 / 44100

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
	    local inp = samples[i]/b
	    local peak = math.abs(inp)*self.gain_p
	    
	    local gain = 0.5 - 0.5*math.tanh(a*(peak))
	    
	    if gain < self.gain_p then
	        self.gain_p = self.gain_p - (self.gain_p - gain)*attack
	    else
	        self.gain_p = self.gain_p - (self.gain_p - gain)*release
	    end
	    

		samples[i] = math.tanh(self.gain_p*inp*b*c)*drywet + samples[i]*(1.0-drywet)
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
		name = "Ratio";
		min = 1;
		max = 25;
		default = 5;
		changed = function (val) a = val end;
	};
	{
		name = "Threshold";
		min = -24;
		max = 0;
		default = -12;
		changed = function (val) b = 10 ^ (val/20.0) end;
	};
		{
		name = "Attack";
		min = 5;
		max = 350;
		default = 25;
		changed = function (val) attack = timeConstant(val) end;
	};
		{
		name = "Release";
		min = 15;
		max = 1000;
		default = 200;
		changed = function (val) release = timeConstant(val) end;
	};
	{
		name = "MakeUp";
		min = 0;
		max = 12;
		default = 0;
		changed = function (val) c = 10 ^ (val/20.0); print(c) end;
	};
}

params.resetToDefaults()