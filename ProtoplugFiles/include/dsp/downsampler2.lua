--[[
FIR 2x downsampler
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

function Downsampler ()
	local buf = ffi.new("double[?]", FILTER_TAP_NUM)

	local pos = 0
	
	return {
		tick = function (s1, s2)
			pos = (pos + 1)%FILTER_TAP_NUM
            buf[pos] = s1

            pos = (pos + 1)%FILTER_TAP_NUM
            buf[pos] = s2

            local s = 0
		    for i = 0,FILTER_TAP_NUM-1,2  do
		        local j = (pos + i)%FILTER_TAP_NUM
		    
		        s = s + filter_taps[i] * buf[j]
		    end
		    
		    local c = (pos + CENTER)%FILTER_TAP_NUM
		    
		    return s + buf[c]*0.5
		end;
	}
end

return Downsampler