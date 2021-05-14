--[[
ising model
stochastic model of spin in a magnetic pickup
too much quantum noise to be useful
]]

require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"

local temp = 0

local n = 256
local l = 32

local iter = 1

local b = 0

local amp = 1

state = {}
energy = {}

for i = 0,n-1 do
    state[i] = 1;
    energy[i] = 0
    if math.random() < 0.5 then
        state[i] = state[i] * (-1)
        
    end
    print(math.random(n)-1)
end


function plugin.processBlock (samples, smax)
    for i = 0, smax do
    
        b = (samples[0][i] +samples[1][i])*0.5
	    
	    --local newstate = {}
	    
	    --local input = samples[0][i]
	    for j = 0,iter do
	        local ind = math.random(n)-1
	        local s = state[ind]
            --sum = sum + s
            
            local e = -s*(state[(ind-1)%n] + state[(ind+1)%n]  + amp*b)
            --local e = -s*(state[(ind-1)%n] + state[(ind+1)%n] + state[(ind-l)%n] + state[(ind+l)%n] + amp*b)
            
            local h = math.exp(  (e) / temp);
            --energy[ind] = h
            if math.random() < h then
                state[ind] = -s
            end
            
        end
        
        local sum = 0
        for j = 0,n-1 do
            local s = state[j]
            sum = sum + s
        end
	    
	    --state = newstate
	    
	    
		local signal = sum/n
		
		
		
		samples[0][i] = signal
		samples[1][i] = signal
	end
end


params = plugin.manageParams {

	{
		name = "T";
		min = 0;
		max = 3;
		changed = function(val) temp = val; end;
	};
    {
		name = "print";
		changed = function(val) print('=======') ; for i = 0,n-1 do print(state[i]) end; end;
	};
	{
		name = "iter";
		min = 0;
		max = 200;
		
		changed = function(val) iter = val; end;
	};
	{
		name = "amp";
		min = 0.5;
		max = 5;
		
		changed = function(val) amp = val; end;
	};

}


 
 