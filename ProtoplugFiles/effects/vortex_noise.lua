--[[
even and odd polynomial distortion

--]]
require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local a = 1.3
local c = -0.8

stereoFx.init()
function stereoFx.Channel:init()
	self.state = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local b = 10 * samples[i]

		local out = a + b * self.state + c * self.state * self.state

		self.state = out

		samples[i] = out
	end
end

--[[params = plugin.manageParams {
	{
		name = "a";
		min = -4;
		max = 4;
		changed = function (val) a = val end;
	};
	{
		name = "c";
		min = -4;
		max = 4;
		changed = function (val) c = val end;
	};
}]]
