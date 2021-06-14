--[[
24 db/o 3 band crossover
perfect reconstruction of magnitude
]]
require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"


local f1 = 500
local f2 = 5000

local lp = {}
local hp = {}

local lp2 = {}
local hp2 = {}
local ap = {}


local qf = math.sqrt(0.5) -- 0.707

stereoFx.init ()
function stereoFx.Channel:init ()
    self.lp_l1 = cbFilter({
		type 	= "lp";
		f 		= 500;
		gain 	= 0;
		Q 		= qf;
	})
	self.lp_l2 = cbFilter({
		type 	= "lp";
		f 		= 500;
		gain 	= 0;
		Q 		= qf;
	})
	table.insert(lp,self.lp_l1)
	table.insert(lp,self.lp_l2)
	
	self.hp_l1 = cbFilter({
		type 	= "hp";
		f 		= 500;
		gain 	= 0;
		Q 		= qf;
	})
	self.hp_l2 = cbFilter({
		type 	= "hp";
		f 		= 500;
		gain 	= 0;
		Q 		= qf;
	})
	table.insert(hp,self.hp_l1)
	table.insert(hp,self.hp_l2)
	
	self.lp_h1 = cbFilter({
		type 	= "lp";
		f 		= 5000;
		gain 	= 0;
		Q 		= qf;
	})
	self.lp_h2 = cbFilter({
		type 	= "lp";
		f 		= 5000;
		gain 	= 0;
		Q 		= qf;
	})
	table.insert(lp2,self.lp_h1)
	table.insert(lp2,self.lp_h2)
	
	self.hp_h1 = cbFilter({
		type 	= "hp";
		f 		= 5000;
		gain 	= 0;
		Q 		= qf;
	})
	self.hp_h2 = cbFilter({
		type 	= "hp";
		f 		= 5000;
		gain 	= 0;
		Q 		= qf;
	})
	table.insert(hp2,self.hp_h1)
	table.insert(hp2,self.hp_h2)
	
	self.ap = cbFilter({
		type 	= "ap";
		f 		= 5000;
		gain 	= 0;
		Q 		= qf;
	})
	table.insert(ap,self.ap)
end

function updateFilters()
    for i,v in ipairs(lp) do
        v.update({f = f1, Q = qf})
    end
    for i,v in ipairs(hp) do
        v.update({f = f1, Q = qf})
    end
    
    for i,v in ipairs(lp2) do
        v.update({f = f2, Q = qf})
    end
    for i,v in ipairs(hp2) do
        v.update({f = f2, Q = qf})
    end
    
    for i,v in ipairs(ap) do
        v.update({f = f2, Q = qf})
    end
end

function stereoFx.Channel:processBlock (samples, smax)
	for i = 0, smax do
		local s = samples[i]
		
		-- first crossover
		local lps = self.lp_l1.process(s)
		lps = self.lp_l2.process(lps)
		
		local hps = self.hp_l1.process(s)
		hps = self.hp_l2.process(hps)
		
	
		-- allpass to correct phase of low band
		local low = self.ap.process(lps)
		--local low = lps
		
		-- second crossover
		local mid = self.lp_h1.process(hps)
		mid = self.lp_h2.process(mid)
		
		local high = self.hp_h1.process(hps)
		high = self.hp_h2.process(high)
		

        local out = low + mid + high
        
		samples[i] = out
	end
end


params = plugin.manageParams {
    {
		name = "f1";
		min = 0;
		max = 1;
		--changed = function (val) f1 = 50*math.exp(math.log(20)*val); updateFilters() end;
		changed = function (val) f1 = 20*math.exp(math.log(1000)*val); updateFilters() end;
	};
	 {
		name = "f2";
		min = 0;
		max = 1;
		--changed = function (val) f2 = 2000*math.exp(math.log(10)*val); updateFilters() end;
		changed = function (val) f2  = 20*math.exp(math.log(1000)*val); updateFilters() end;
	};
}
