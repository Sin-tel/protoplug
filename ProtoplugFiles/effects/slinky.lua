--[[
simulate slinky delay with characteristic frequency sweep
]]

require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"
local Line = require "include/dsp/delay_line"

local kap = 0.625
local l = 100
local len = 20
local feedback = 0
local time = 1

stereoFx.init ()

function softclip(x) 
    if x <= -1.5 then
        return -1
    elseif x >= 1.5 then
        return 1
    else
        return x - (4/27)*x*x*x
    end
end

function stereoFx.Channel:init ()
	-- create per-channel fields (filters)
	self.ap = {}
	self.len = {}
	self.k = {}
	for i=1,1000 do
	    self.ap[i] = 0
	    self.len[i] = math.random()
	    self.k[i] = math.random()
	end
	self.time = 0
	self.last = 0
	
	self.delay = Line(20000)
end

function stereoFx.Channel:processBlock (samples, smax)
	for i = 0, smax do
	    self.time = self.time + 1/44100

	    local input = samples[i]
		
		local s = input - softclip(self.delay.goBack_int(18000*time))*feedback --+ 0.0001*(math.random()-0.5)
		
		for i = 1,l do
		    --local d = self.ap[i].goBack_int(self.len[i]*time + 2*math.sin(10*self.time)) 
		    local d = self.ap[i]
		    local v = s + kap * d
		    
		    
		   -- v = softclip(v)
	        s = -kap*v + d
	        
	        --v = softclip(v)
	        self.ap[i] = v
		end
		
		local signal =  s -- input*(kap^l)
		self.delay.push(signal)
		
		
		samples[i] = input*(1.0-balance) + signal*balance
		
		
	end
end

local function updateFilters(filters,args)
	for _, f in pairs(filters) do
		f.update(args)
	end
end

params = plugin.manageParams {
	{
		name = "Dry/Wet";
		min = 0;
		max = 1;
		changed = function(val) balance = val end;
	};
	{
		name = "iter";
	    min = 0;
		max = 1000;
		type = "int";
		changed = function(val) l = val end;
	};
	{
		name = "kap";
	    min = 0;
		max = 6;
		changed = function(val) kap = 1-math.exp(-val) end;
	};
	{
		name = "feedback";
	    min = 0;
		max = 1;
		changed = function(val) feedback = val end;
	};
	{
		name = "time";
	    min = 0.01;
		max = 1;
		changed = function(val) time = val end;
	};
	{
		name = "seed";
	    min = 0;
		max = 100;
		type = "int";
		changed = function(val) 
		    math.randomseed(val);
		    for i=1,100 do
                stereoFx.LChannel.len[i] = math.random(900)+90;
                stereoFx.RChannel.len[i] = math.random(900)+90;
            end
		end;
	};
}
 