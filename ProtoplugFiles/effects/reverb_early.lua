--[[
tapped delay decorrelators
]]

require "include/protoplug"
local cbFilter = require "include/dsp/cookbook filters"
local Line = require "include/dsp/delay_line"

tapl = {
	 1 ,
	 150 ,
	 353 ,
	 546 ,
	 661 ,
	 683 ,
	 688 ,
	 1144 ,
	 1770 ,
	 2359 ,
	 2387 ,
	 2441 ,
	 2469 ,
	 2662 ,
	 2705 ,
	 3057 ,
	 3084 ,
	 3241 ,
	 3413 ,
	 3610 ,
}
ampl = {
	 0.6579562483759885 ,
	 0.24916228159437137 ,
	 -0.5122038920577012 ,
	 0.36330673539935077 ,
	 -0.4333746605125533 ,
	 -0.4577140871718608 ,
	 0.49781845692600857 ,
	 -0.18939379696133735 ,
	 -0.2742675178348754 ,
	 -0.026542803499400146 ,
	 0.14192882965401657 ,
	 -0.13860435085891593 ,
	 0.0465555003986965 ,
	 -0.044959474245282856 ,
	 -0.14768870058256517 ,
	 -0.08116161585856699 ,
	 -0.046801445561742955 ,
	 -0.0979962170313839 ,
	 -0.04455145315483788 ,
	 0.08921755954681033 ,
}


tapr = {
	 1 ,
	 21 ,
	 793 ,
	 967 ,
	 1159 ,
	 1202 ,
	 1742 ,
	 1862 ,
	 2069 ,
	 2164 ,
	 2471 ,
	 2473 ,
	 3126 ,
	 3272 ,
	 3328 ,
	 3352 ,
	 3459 ,
	 3622 ,
	 3666 ,
	 3789 ,
}
ampr = {
	 0.29755424362094174 ,
	 0.9032103522197956 ,
	 0.30566236871633573 ,
	 -0.14208683332676209 ,
	 0.13793374915217088 ,
	 0.1019480721591429 ,
	 -0.20205322951447593 ,
	 0.10501607467781215 ,
	 0.23692289191968258 ,
	 0.0501838324018514 ,
	 0.07338616539393834 ,
	 0.09096667690763441 ,
	 -0.1218410929057997 ,
	 0.07558917751391205 ,
	 0.12901113392801317 ,
	 0.07933521679736777 ,
	 -0.08103780888639031 ,
	 0.041229283316782016 ,
	 -0.07247541530737873 ,
	 0.07164683067383586 ,
}

tmult = 1.0

pre_t = 50

--- init
line_l = Line(4000)
line_r = Line(4000)

pre_l = Line(4000)
pre_r = Line(4000)


	
function plugin.processBlock (samples, smax)
	for i = 0, smax do
	    local input_l = samples[0][i]
        local input_r = samples[1][i]
	    
        local sl = 0
        local sr = 0

        for i,v in ipairs(tapl) do
        	sl = sl + line_l.goBack_int(tapl[i]*tmult) * ampl[i]
        	sr = sr + line_r.goBack_int(tapr[i]*tmult) * ampr[i]
        end
        
        pl = pre_l.goBack_int(pre_t)
        pr = pre_r.goBack_int(pre_t)
        
	    line_l.push(pl)
	    line_r.push(pr)
	    
	    pre_l.push(input_l)
	    pre_r.push(input_r)

		samples[0][i] = input_l*(1.0-balance) + sl*balance
		samples[1][i] = input_r*(1.0-balance) + sr*balance
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
		name = "PreDelay";
		min = 0;
		max = 60;
		
		changed = function(val) pre_t = 1 + val*44100/1000; print(pre_t) end;
	};
	{
		name = "Time";
		min = 0.1;
		max = 1;
		changed = function(val) tmult = val end;
	};
}
  