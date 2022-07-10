--[[
FIR 2x upsampler
11 taps
kaiser window, beta = 6

optimized version
]]

local bit = require("bit")

local band = bit.band

local function Upsampler()
	local buf = ffi.new("double[?]", 16)

	local pos = 0

	return {
		tick = function(s)
			pos = band(pos + 1, 15)
			buf[pos] = 2 * s

			local s1 = 0
			-- stylua: ignore start
			s1 = s1 + 0.000946866048198065 * (buf[pos]                + buf[band(pos -  5, 15)])
			s1 = s1 - 0.035970933008718849 * (buf[band(pos -  1, 15)] + buf[band(pos -  4, 15)])
			s1 = s1 + 0.285014730719374387 * (buf[band(pos -  2, 15)] + buf[band(pos -  3, 15)])
			-- stylua: ignore end

			local s2 = 0
			s2 = s2 + 0.5 * buf[band(pos - 2, 15)]

			return s1, s2
		end,
	}
end

return Upsampler
