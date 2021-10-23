--[[
FIR 2x upsampler
11 taps
kaiser window, beta = 6

optimized version
]]

local bit = require("bit")

local band = bit.band

function Upsampler()
	local buf_l = ffi.new("double[?]", 16)
	local buf_h = ffi.new("double[?]", 16)

	local pos = 0
	
	return {
		tick = function (s_lp, s_hp)
			pos = band(pos + 1,15)
			buf_l[pos] = 2*(s_lp)
			buf_h[pos] = 2*(s_hp)

			local s1 = 0
			s1 = s1 + 1.1698262618555022e-04 * (buf_l[pos]                - buf_h[pos])
			s1 = s1 - 4.2020464463563348e-03 * (buf_l[band(pos -  4, 15)] - buf_h[band(pos -  4, 15)])
			s1 = s1 - 2.5739172040044011e-02 * (buf_l[band(pos -  1, 15)] - buf_h[band(pos -  1, 15)])
			s1 = s1 + 9.7906199427176821e-02 * (buf_l[band(pos -  3, 15)] - buf_h[band(pos -  3, 15)])
			s1 = s1 + 4.2978344742322788e-01 * (buf_l[band(pos -  2, 15)] - buf_h[band(pos -  2, 15)])

			local s2 = 0
			s2 = s2 + 1.1698262618555022e-04 * (buf_l[band(pos -  4, 15)] + buf_h[band(pos -  4, 15)])
			s2 = s2 - 4.2020464463563348e-03 * (buf_l[pos]                + buf_h[pos]               )
			s2 = s2 - 2.5739172040044011e-02 * (buf_l[band(pos -  3, 15)] + buf_h[band(pos -  3, 15)])
			s2 = s2 + 9.7906199427176821e-02 * (buf_l[band(pos -  1, 15)] + buf_h[band(pos -  1, 15)])
			s2 = s2 + 4.2978344742322788e-01 * (buf_l[band(pos -  2, 15)] + buf_h[band(pos -  2, 15)])

			return s1, s2
		end;
	}
end

return Upsampler