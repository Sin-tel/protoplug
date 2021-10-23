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
			s = s + 1.1698262618555022e-04 * (buf[pos]                + buf[band(pos -  9, 15)])
			s = s - 4.2020464463563348e-03 * (buf[band(pos -  1, 15)] + buf[band(pos -  8, 15)])
			s = s - 2.5739172040044011e-02 * (buf[band(pos -  2, 15)] + buf[band(pos -  7, 15)])
			s = s + 9.7906199427176821e-02 * (buf[band(pos -  3, 15)] + buf[band(pos -  6, 15)])
			s = s + 4.2978344742322788e-01 * (buf[band(pos -  4, 15)] + buf[band(pos -  5, 15)])

			local w = 0
			w = w + 1.1698262618555022e-04 * ( buf[pos]                - buf[band(pos -  9, 15)])
			w = w - 4.2020464463563348e-03 * (-buf[band(pos -  1, 15)] + buf[band(pos -  8, 15)])
			w = w - 2.5739172040044011e-02 * ( buf[band(pos -  2, 15)] - buf[band(pos -  7, 15)])
			w = w + 9.7906199427176821e-02 * (-buf[band(pos -  3, 15)] + buf[band(pos -  6, 15)])
			w = w + 4.2978344742322788e-01 * ( buf[band(pos -  4, 15)] - buf[band(pos -  5, 15)])

			return s, w
		end;
	}
end

return Downsampler