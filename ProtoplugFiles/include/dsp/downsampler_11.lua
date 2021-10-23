--[[
FIR 2x downsampler
11 taps
kaiser window, beta = 6

optimized version
]]

local bit = require("bit")

local band = bit.band

function Downsampler ()
	local buf = ffi.new("double[?]", 16)

	local pos = 0
	
	return {
		tick = function (s1, s2)
			pos = band(pos + 1,15)
			buf[pos] = s1
			pos = band(pos + 1,15)
			buf[pos] = s2

			local s = 0
			s = s + 0.000946866048198065 * (buf[pos]                + buf[band(pos - 10, 15)])
			s = s - 0.035970933008718849 * (buf[band(pos -  2, 15)] + buf[band(pos -  8, 15)])
			s = s + 0.285014730719374387 * (buf[band(pos -  4, 15)] + buf[band(pos -  6, 15)])

			s = s + 0.5 * buf[band(pos - 5,15)]

			return s
		end;
	}
end

return Downsampler