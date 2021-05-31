--[[
terrible distortion 
sounds pretty good
]]
require "include/protoplug"
local cbFilter = require "include/dsp/svf_nonlinear"




local gain = 0

local freq = 0.5
local res = 1

local db_to_exp = math.log(10) / 20

local filters = {}

stereoFx.init ()
function stereoFx.Channel:init ()
    self.s = 0
	
	self.filter = Svf()
	self.filter.update(0.5,10)
	
	table.insert(filters, self.filter)
end

function updateFilters()
    for i,v in ipairs(filters) do
        v.update(freq,res)
    end
end

function stereoFx.Channel:processBlock (samples, smax)
	for i = 0, smax do
		local inp = samples[i]
		
		local hp, bp, lp
		
		lp, bp, hp = self.filter.process(inp)
		

        local out = lp
	
		samples[i] = out
	end
end


params = plugin.manageParams {
    {
		name = "freq";
		min = 0;
		max = 1;
		changed = function (val) freq = 20*math.exp(math.log(1000)*val)/44100; updateFilters() end;
	};
	{
		name = "resonance";
		min = 0.01;
		max = 2;
		changed = function (val) res = -math.log(val); updateFilters() end;
	};
}
