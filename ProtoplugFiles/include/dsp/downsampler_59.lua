--[[
FIR 2x downsampler
59 taps
kaiser window, beta = 8

optimized version
]]

local bit = require("bit")

local band = bit.band

function Downsampler ()
	local buf = ffi.new("double[?]", 64)

	local pos = 0
	
	return {
		tick = function (s1, s2)
			pos = band(pos + 1,63)
			buf[pos] = s1
			pos = band(pos + 1,63)
			buf[pos] = s2

			local s = 0
			s = s + 2.567147842452834554e-05 * (buf[pos]                + buf[band(pos - 58, 63)])
			s = s - 1.261090868996386978e-04 * (buf[band(pos -  2, 63)] + buf[band(pos - 56, 63)])
			s = s + 3.527441024595549422e-04 * (buf[band(pos -  4, 63)] + buf[band(pos - 54, 63)])
			s = s - 7.870753313197489075e-04 * (buf[band(pos -  6, 63)] + buf[band(pos - 52, 63)])
			s = s + 1.537346765088283725e-03 * (buf[band(pos -  8, 63)] + buf[band(pos - 50, 63)])
			s = s - 2.741966910244973341e-03 * (buf[band(pos - 10, 63)] + buf[band(pos - 48, 63)])
			s = s + 4.575452401257772486e-03 * (buf[band(pos - 12, 63)] + buf[band(pos - 46, 63)])
			s = s - 7.261804399124320575e-03 * (buf[band(pos - 14, 63)] + buf[band(pos - 44, 63)])
			s = s + 1.110611491158913777e-02 * (buf[band(pos - 16, 63)] + buf[band(pos - 42, 63)])
			s = s - 1.657002672244152139e-02 * (buf[band(pos - 18, 63)] + buf[band(pos - 40, 63)])
			s = s + 2.446043717114812846e-02 * (buf[band(pos - 20, 63)] + buf[band(pos - 38, 63)])
			s = s - 3.645662241698729988e-02 * (buf[band(pos - 22, 63)] + buf[band(pos - 36, 63)])
			s = s + 5.691759360466236428e-02 * (buf[band(pos - 24, 63)] + buf[band(pos - 34, 63)])
			s = s - 1.019292916787690184e-01 * (buf[band(pos - 26, 63)] + buf[band(pos - 32, 63)])
			s = s + 3.168967333911719697e-01 * (buf[band(pos - 28, 63)] + buf[band(pos - 30, 63)])


			s = s + 0.5 * buf[band(pos - 29,63)]

			return s
		end;
	}
end

return Downsampler