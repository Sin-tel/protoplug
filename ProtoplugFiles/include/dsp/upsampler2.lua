--[[
FIR 2x upsampler
kaiser window, beta = 6
]]

local FILTER_TAP_NUM = 31

local CENTER = 15

local filter_taps = ffi.new("double[?]", FILTER_TAP_NUM,{ [0] =
 -3.15622016e-04,  0.00000000e+00,  1.76790330e-03,  0.00000000e+00,
 -5.20927712e-03,  0.00000000e+00,  1.19903110e-02,  0.00000000e+00,
 -2.42536137e-02,  0.00000000e+00,  4.65939093e-02,  0.00000000e+00,
 -9.50049102e-02,  0.00000000e+00,  3.14457346e-01,  5.00000000e-01,
  3.14457346e-01,  0.00000000e+00, -9.50049102e-02,  0.00000000e+00,
  4.65939093e-02,  0.00000000e+00, -2.42536137e-02,  0.00000000e+00,
  1.19903110e-02,  0.00000000e+00, -5.20927712e-03,  0.00000000e+00,
  1.76790330e-03,  0.00000000e+00, -3.15622016e-04}) 

function Upsampler ()
	local buf = ffi.new("double[?]", FILTER_TAP_NUM)

	local pos = 0
	
	return {
		tick = function (s)
			pos = (pos + 1)%FILTER_TAP_NUM
            buf[pos] = s*2

            local s1 = 0
		    for i = 0,FILTER_TAP_NUM-1  do
		        local j = (pos + i)%FILTER_TAP_NUM
		    
		        s1 = s1 + filter_taps[i] * buf[j]
		    end
		    
		    pos = (pos + 1)%FILTER_TAP_NUM
            buf[pos] = 0

            local s2 = 0
		    for i = 0,FILTER_TAP_NUM-1  do
		        local j = (pos + i)%FILTER_TAP_NUM
		    
		        s2 = s2 + filter_taps[i] * buf[j]
		    end
		    
		    return s1, s2 
		end;
	}
end

return Upsampler