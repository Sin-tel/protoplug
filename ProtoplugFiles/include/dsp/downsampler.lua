--[[
FIR 2x downsampler
kaiser window, beta = 6

optimized version
]]

local bit = require("bit")

local band = bit.band

function Downsampler ()
	local buf = ffi.new("double[?]", 32)

	local pos = 0
	
	return {
		tick = function (s1, s2)
			pos = band(pos + 1,31)
            buf[pos] = s1
            pos = band(pos + 1,31)
            buf[pos] = s2

            local s = 0--ffi.new("double")
	        s = s - 3.15622016e-04 * (buf[pos]                + buf[band(pos - 30, 31)])
	        s = s + 1.76790330e-03 * (buf[band(pos -  2, 31)] + buf[band(pos - 28, 31)])
	        s = s - 5.20927712e-03 * (buf[band(pos -  4, 31)] + buf[band(pos - 26, 31)])
	        s = s + 1.19903110e-02 * (buf[band(pos -  6, 31)] + buf[band(pos - 24, 31)])
	        s = s - 2.42536137e-02 * (buf[band(pos -  8, 31)] + buf[band(pos - 22, 31)])
	        s = s + 4.65939093e-02 * (buf[band(pos - 10, 31)] + buf[band(pos - 20, 31)])
	        s = s - 9.50049102e-02 * (buf[band(pos - 12, 31)] + buf[band(pos - 18, 31)])
	        s = s + 3.14457346e-01 * (buf[band(pos - 14, 31)] + buf[band(pos - 16, 31)])

	        s = s + 0.5 * buf[band(pos - 15,31)]
		    
		    return s
		end;
	}
end

return Downsampler