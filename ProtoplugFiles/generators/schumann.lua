--[[
simulated schumann resonances of the atmosphere 

--]]

require "include/protoplug"

n = 10
t = 0
a = 5.54
phases = {}
for i = 1,1000 do
    phases[i] = math.random()*2*3.1415
end

function plugin.processBlock(s, smax)
    for i = 0,smax do
        
        t = t + a/44100
        
        
        local out = 0
        for i = 1,n do
            out = out + math.sin(phases[i]+t*math.sqrt(i*(i+1)))/i
        end
        out = out 
        s[0][i] = out
        s[1][i] = out
    end
    
end




params = plugin.manageParams {
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	{
		name = "a";
		min = 0;
		max = 10;
		default = 5.54;
		changed = function(val) a = val end;
	};
	{
		name = "n";
		min = 0;
		max = 500;
		default = 10;
		changed = function(val) n = val end;
	};
}

