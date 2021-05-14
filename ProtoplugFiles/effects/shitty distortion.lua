--[[
terrible distortion 
sounds pretty good
]]
require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"

local a = 0
local b = 0
local c = 0



stereoFx.init ()
function stereoFx.Channel:init ()
    self.s = 0
	
	self.high = cbFilter {type = "hp"; f = 50; gain = 0; Q = 0.7}
end

function stereoFx.Channel:processBlock (samples, smax)
	for i = 0, smax do
		self.s = math.tanh(a*samples[i] + b + c*self.s)
		self.s = self.high.process(self.s)

	
		samples[i] = self.s
	end
end

params = plugin.manageParams {
	{
		name = "amp";
		min = 0;
		max = 2;
		changed = function (val) a = val end;
	};
	{
		name = "bias";
		min = 0;
		max = 2;
		changed = function (val) b = val end;
	};
		{
		name = "feedback";
		min = 0;
		max = 2;
		changed = function (val) c = val end;
	};
}
