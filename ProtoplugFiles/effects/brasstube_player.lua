require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"

local lp2filters = {}



local len = 500

local beta = 0.05

local time = 0

local pressure = 0


local line = {}
for i = 1,len do
    line[i] = 0
end
local line2 = {}
for i = 1,len do
    line[i] = 0
end
	
local high = cbFilter {type = "hp"; f = 20; gain = 0; Q = 0.7}

local lip = cbFilter
	{
		type 	= "lp";
		f 		= 12000;
		gain 	= 0;
		Q 		= 10.0;
	}
	
local lp2 = cbFilter
	{
		type 	= "lp";
		f 		= 12000;
		gain 	= 0;
		Q 		= 0.707;
	}
	



function plugin.processBlock (samples, smax)
    for i = 0, smax do
	    time = time + 1/44100
	
	    
	    local feedback = line[len-1]*0.85--high.process(line[len-1])
	    
	    --feedback = lp2.process(feedback)*0.85
	    local pressure = pressure 
	    
	    local deltaP = pressure - feedback
	    deltaP = lip.process(deltaP)
	    deltaP = deltaP*math.max(0,deltaP)
	    deltaP =  deltaP * (1.0 + 0.02*math.random())
	    if deltaP > 1.0 then
	        deltaP = 1.0
	    end
	    
	    
	    
	    local s = deltaP * pressure + (1.0 - deltaP) * feedback
	    s  = high.process(s)
	    --s = math.max(math.min(s,1),0)
	    
	    line2[1] = s
	    line[0] = s
	    for i = 2,len do
	        local e = beta*(0.5+0.5*line[i-1])
	        e = math.max(math.min(e,1),0)
	        
	        
            line2[i] = (1-e)*line[i-1] + e*line[i-2]
        end
        
        --swap buffers
        line, line2 = line2, line
	    
	    
		local signal = line[math.floor(len/2)]
		
		
		
		samples[0][i] = signal
		samples[1][i] = signal
	end
end


params = plugin.manageParams {
    {
		name = "Pressure";
		min = 0;
		max = 1;
		changed = function(val) pressure = val; end;
	};

	{
		name = "Lip Freq";
		min = 0;
		max = 16;
		changed = function(val) lip.update({f=(44100/(len+10))*val}); end;
	};
	{
		name = "Lip Q";
		min = 1;
		max = 50;
		changed = function(val) lip.update({Q=val}); end;
	};
	
}


 
 