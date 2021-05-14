require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"
local Line = require "include/dsp/delay_line"

local kap = 0.625
local l = 100
local len = 20
local feedback = 0

stereoFx.init ()
function stereoFx.Channel:init ()
	-- create per-channel fields (filters)
	self.ap = {}
	self.len = {}
	for i=1,100 do
	    self.ap[i] = Line(500)
	    self.len[i] = math.random(300)+110
	end
	--self.ap1 = Line(2000)
	self.last = 0
end

function stereoFx.Channel:processBlock (samples, smax)
	for i = 0, smax do
	    

	    local input = samples[i]
	    
	    --local d = self.ap1.goBack_int(500) 
		--local v = input - kap * d
		--local signal = kap*v + d
		
		local s = input + self.last*feedback
		
		for i = 1,l do
		    local d = self.ap[i].goBack_int(self.len[i]) 
		    local v = s - kap * d
	        s = kap*v + d
	        
	        
	        self.ap[i].push(v)
		end
		
		self.last = s
		local signal = s
		
		
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
		max = 100;
		type = "int";
		changed = function(val) l = val end;
	};
	{
		name = "kap";
	    min = 0;
		max = 1;
		changed = function(val) kap = val end;
	};
	{
		name = "feedback";
	    min = 0;
		max = 1;
		changed = function(val) feedback = val end;
	};
}
 