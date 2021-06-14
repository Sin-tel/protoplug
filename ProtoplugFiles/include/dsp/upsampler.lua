--[[
FIR 2x upsampler
kaiser window, beta = 6

optimized version
]]

local bit = require("bit")

local band = bit.band

function Downsampler ()
	local buf = ffi.new("double[?]", 32)

	local pos = 0
	
	return {
		tick = function (s)
			pos = band(pos + 1,31)
			buf[pos] = 2*s

			local s1 = 0
			s1 = s1 - 3.15622016e-04 * (buf[pos]               + buf[band(pos - 15, 31)])
			s1 = s1 + 1.76790330e-03 * (buf[band(pos - 1, 31)] + buf[band(pos - 14, 31)])
			s1 = s1 - 5.20927712e-03 * (buf[band(pos - 2, 31)] + buf[band(pos - 13, 31)])
			s1 = s1 + 1.19903110e-02 * (buf[band(pos - 3, 31)] + buf[band(pos - 12, 31)])
			s1 = s1 - 2.42536137e-02 * (buf[band(pos - 4, 31)] + buf[band(pos - 11, 31)])
			s1 = s1 + 4.65939093e-02 * (buf[band(pos - 5, 31)] + buf[band(pos - 10, 31)])
			s1 = s1 - 9.50049102e-02 * (buf[band(pos - 6, 31)] + buf[band(pos -  9, 31)])
			s1 = s1 + 3.14457346e-01 * (buf[band(pos - 7, 31)] + buf[band(pos -  8, 31)])

			local s2 = 0
			s2 = s2 + 0.5 * buf[band(pos - 7,31)]
			
			return s1, s2
		end;
	}
end

return Downsampler