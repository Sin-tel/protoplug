--[[
Proper stereo reverb
]]

require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"
local Line = require "include/dsp/fdelay_line"

local balance = 1.0

local kap = 0.5 -- 0.625

local l1 = 2687	
local l2 = 4349
local l3 = 5227
local l4 = 7547

local feedback = 0.4

local time = 1.0
local t_60 = 1.0


--- init
line1 = Line(8000)
line2 = Line(8000)
line3 = Line(8000)
line4 = Line(8000)

apl = {}
apr = {}
apln = {}
aprn = {}
for i = 1, 3 do
    apl[i] = Line(800)
    apr[i] = Line(800)
end	
apln[1] = 41
apln[2] = 389
apln[3] = 227

aprn[1] = 53
aprn[2] = 347
aprn[3] = 251

lfot = 0

-- absorption filters
shelf1 = cbFilter
{
	type 	= "hs";
	f 		= 8000;
	gain 	= -3;
	Q 		= 0.7;
}

shelf2 = cbFilter
{
	type 	= "hs";
	f 		= 8000;
	gain 	= -3;
	Q 		= 0.7;
}

time_ = 1.0
	


function plugin.processBlock (samples, smax)
	for i = 0, smax do
	    lfot = lfot + 1/44100
	    
	    local mod  = 1.0 + 0.005 * math.sin(5.35*lfot)
	    local mod2 = 1.0 + 0.008 * math.sin(3.12*lfot)
	    
	    time_ = time_ - (time_  - time)*0.001
	    
	
	    local input_l = samples[0][i]
        local input_r = samples[1][i]
	    
	    local sl = input_l
	    local sr = input_r
		
		
		-- allpasses
		for i = 1,3 do
		    local d = apl[i].goBack_int(apln[i]) 
		    local v = sl - kap * d
	        sl = kap*v + d
	        apl[i].push(v)
	    end

	    for i = 1,3 do
		    local d = apr[i].goBack_int(aprn[i]) 
		    local v = sr - kap * d
	        sr = kap*v + d
	        apr[i].push(v)
	    end
	    

	    -- FDN network
	    local d1 = line1.goBack(l1*time_)
	    local d2 = line2.goBack(l2*time_) 
	    local d3 = line3.goBack(l3*time_*mod) 
	    local d4 = line4.goBack(l4*time_*mod2) 
	    
	    local gain = feedback * 0.5
	    
	    -- Hadamard matrix
	    local s1 = shelf1.process(sl + ( d1 + d2 + d3 + d4) * gain)
	    local s2 = shelf2.process(sr + ( d1 - d2 + d3 - d4) * gain)
	    local s3 =               (sl + ( d1 + d2 - d3 - d4) * gain)
	    local s4 =               (sr + ( d1 - d2 - d3 + d4) * gain)
	    
	    line1.push(s1)
	    line2.push(s2)
	    line3.push(s3)
	    line4.push(s4)
		
		sl = 0.5 * (d1 + d3)
		sr = 0.5 * (d2 + d4)

		
		samples[0][i] = input_l*(1.0-balance) + sl*balance
		samples[1][i] = input_r*(1.0-balance) + sr*balance
	end
end

function setFeedback(t)
    
    if t then
        t_60 = t
    end
    --print(t_60)
    if t_60 > 15 then
        feedback = 1.0
    else
        feedback = 10 ^ (- (60 * 4000 * time) / (t_60 * 44100*20))
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
		name = "Size";
		min = 0.3;
		max = 1;
		changed = function(val) time = val; setFeedback() end;
	};
	{
		name = "Decay Time";
		min = 0;
		max = 1;
		changed = function(val) setFeedback(2 ^ (8*val - 4)) end;
	};
}
  