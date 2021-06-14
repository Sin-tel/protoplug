require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"
local Line = require "include/dsp/delay_line"

local kap = 0.625
local l = 32
local max_l = 32
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
	for i=1,max_l do
	    self.ap[i] = Line(4000)
	    self.len[i] = math.random(900)+90
	end
	self.t = 0
	self.last = 0
	--self.ap1 = Line(2000)
	
	self.high = cbFilter {type = "hp"; f = 200; gain = 0; Q = 0.7}
	
	self.low = cbFilter
	{
		type 	= "hs";
		f 		= 10000;
		gain 	= -2;
		Q 		= 0.7;
	}
	
	self.time = 1
	self.kap = kap
end

function stereoFx.Channel:processBlock (samples, smax)
	for i = 0, smax do
	    self.t = self.t + 1/44100

	    local input = samples[i]
	    
	    self.time = self.time + 0.0005*(time - self.time)
	    self.kap = self.kap + 0.001*(kap - self.kap)
	    
	    local nt = self.time * (1.0 + 0.003*math.sin(3*self.t))
	    
	    local s = input - self.last*feedback + 0.00001*(math.random()-0.5)

		--local eps = 0.001
	    --s = s - math.max(-eps,math.min(eps,s))
		
		s = self.low.process(s)
		s = self.high.process(s)
		

		s = 0.01 + s + 0.01*s*s
		s = math.tanh(s)
		
		
	    --self.last = math.floor(self.last*16)/16
		
		--local s = input - self.last*feedback + 0.0001*(math.random()-0.5)
		
		local s_pre = s
		
		for i = 1,l do
		    --local d = self.ap[i].goBack_int(self.len[i]*time + 5*math.sin(10*self.t + i)) 
		    --local d = self.ap[i].goBack_int(self.len[i]*time + 0.01*(math.random() - math.random()) )
		    local d = self.ap[i].goBack_int(self.len[i]*nt) 
		    
		    --s = softclip(s*1.05)
		    
		    local v = s - self.kap * d
		    
		    
		    
		   -- v = softclip(v)
		    --v = math.tanh(v)
	        s = self.kap*v + d
	        
	        --s = math.tanh(s)
	        
	        --v = softclip(v)
	       -- v = math.tanh(v)
	        self.ap[i].push(v)
		end
		
		local signal =  s - s_pre*(self.kap^l)
		--local signal =  s
		self.last = signal
		
		
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
		max = 32;
		type = "int";
		changed = function(val) l = val end;
	};
	{
		name = "kap";
	    min = 0;
		max = 4;
		changed = function(val) kap = 1-math.exp(-val) end;
	};
	{
		name = "feedback";
	    min = 0;
		max = 1.1;
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
		max = max_l;
		type = "int";
		changed = function(val) 
		    math.randomseed(val);
		    for i=1,max_l do
                stereoFx.LChannel.len[i] = math.random(2000)+2000;
                stereoFx.RChannel.len[i] = math.random(2000)+2000;
            end
		end;
	};
}
  