require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"

Line = require "include/dsp/delay_line"

local lp2filters = {}



local len = 100

local beta = 0.1

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

delay = Line(1024)
delaylength = 500
	
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
	

local noisefilter = cbFilter
	{
		type 	= "lp";
		f 		= 1000;
		gain 	= 0;
		Q 		= 0.707;
	}


function plugin.processBlock (samples, smax)
    for i = 0, smax do
	    time = time + 1/44100
	
	    local nse = math.random() - 0.5
	    
	    nse = noisefilter.process(nse)
	    
	    local feedback = delay.goBack(delaylength)*0.8--line[len-1]*0.85--high.process(line[len-1])
	    
	    --feedback = lp2.process(feedback)*0.85
	    local pressure = pressure 
	    
	    local deltaP = pressure - feedback
	    deltaP = lip.process(deltaP)
	    deltaP = math.max(0,deltaP)*deltaP
	    deltaP =  deltaP * (1.0 + 0.2*nse)
	    if deltaP > 1.0 then
	        deltaP = 1.0
	    end
	    
	    
	    
	    local s = deltaP * pressure + (1.0 - deltaP) * feedback
	    s  = high.process(s)
	    --s = math.max(math.min(s,1),0)
	    
	    line2[1] = s
	    line[0] = s
	    for i = 2,len do
	        local sum = line[i-1] + line[len-i]
	        
	        local e = beta*(0.5+0.25*sum)
	        
	        --this seems reasonable but it sounds better without
	        --e = math.max(math.min(e,1),0)
	        
           line2[i] = (1-e)*line[i-1] + e*line[i-2]
        end
        
        --swap buffers
        line, line2 = line2, line
	    
	    delay.push(line[len-1])
	    
		local signal = line[len-1]
		
		
		
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
		changed = function(val) lip.update({f=(44100/(len+delaylength))*val}); end;
	};
	{
		name = "Lip Q";
		min = 1;
		max = 50;
		changed = function(val) lip.update({Q=val}); end;
	};
	{
		name = "beta";
		min = 0;
		max = 0.2;
		changed = function(val) beta = val; end;
	};
	{
		name = "delaytime";
		min = 0;
		max = 1000;
		changed = function(val) delaylength = val; end;
	};
	
}


 
 