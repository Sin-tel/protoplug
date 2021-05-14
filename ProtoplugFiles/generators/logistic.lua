--[[
iterated logistic map
can be used as a noise source
--]]

require "include/protoplug"

t = 0
out = 0.1
r = 1

function plugin.processBlock(s, smax)
    for i = 0,smax do
        
        t = t + 1
        if(t >5) then
            t = 0
            
            out = r*out*(1-out)
        end
        s[0][i] = out
        s[1][i] = out
    end
    
end




params = plugin.manageParams {
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	{
		name = "Mu";
		min = 3.5;
		max = 3.99;
		default = 0;
		changed = function(val) r = val end;
	};
	{
		name = "Drive";
		min = 0;
		max = 0.1;
		default = 0;
		changed = function(val) a = val end;
	};
}

