--[[
even and odd polynomial distortion

--]]
require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"

local slew = 0.1
local mix = 1
local gain = 1

local db_to_exp = math.log(10) / 20

stereoFx.init ()
function stereoFx.Channel:init ()
	-- create per-channel fields (filters)
	
	-- self.high = cbFilter {type = "hp"; f = 20; gain = 0; Q = 0.3}
	
	self.state = 0
end

function stereoFx.Channel:processBlock (samples, smax)
	for i = 0, smax do
	
	    local dry = samples[i]
	    
		local s = gain*dry
		
		local diff = (s - self.state)
		
		diff = math.min(diff, slew)
		diff = math.max(diff, -slew)
		
		local out = self.state + diff
		
		self.state = out
		
		
		samples[i] = (1-mix)*s + mix*out
	end
end

params = plugin.manageParams {
    {
		name = "dry/wet";
		min = 0;
		max = 1;
		default = 1;
		changed = function (val) mix = val end;
	};
	{
		name = "slew time";
		min = 0;
		max = 1;
		default = 0.3;
		changed = function (val) slew = math.exp(-val*10) end;
	};
	{
		name = "gain (dB)";
		min = -6;
		max = 12;
		default = 0;
		changed = function (val) gain = math.exp(db_to_exp * val) end;
	};
	
}


params.resetToDefaults()