--[[
lower bit resolution with mu law companding
]]
require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"

local bdepth
local m

local function sign(x)
	if x > 0 then
	    return 1
	else
	    return -1
	end
end

stereoFx.init ()
function stereoFx.Channel:init ()
	-- create per-channel fields (filters)
	
	self.high = cbFilter {type = "hp"; f = 20; gain = 0; Q = 0.3}
end

function stereoFx.Channel:processBlock (samples, smax)
	for i = 0, smax do
	
	    local s = samples[i]
	    local u = sign(s) * math.log(1+m*math.abs(s)) / math.log(1+m)
	    
	    u = math.floor(bdepth * u) / bdepth
	    
	    local c = sign(u)*(math.pow(1+m,math.abs(u))-1)/m
		
		samples[i] = c
	end
end

params = plugin.manageParams {
	{
		name = "bits";
		min = 1;
		max = 8;
		changed = function (val) bdepth = math.pow(2,val) end;
	};
	{
		name = "m";
		min = 1;
		max = 255;
		changed = function (val) m = val end;
	};
}
