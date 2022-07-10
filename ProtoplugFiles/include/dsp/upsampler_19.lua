--[[
FIR 2x upsampler
19 taps
kaiser window, beta = 6

optimized version
]]

local bit = require("bit")

local band = bit.band

function Upsampler()
	local buf = ffi.new("double[?]", 16)

	local pos = 0

	return {
		tick = function(s)
			pos = band(pos + 1, 15)
			buf[pos] = 2 * s

			local s1 = 0
			-- stylua: ignore start
			s1 = s1 + 0.000526036693443370 * (buf[pos]                + buf[band(pos - 9, 15)])
			s1 = s1 - 0.006280266471956432 * (buf[band(pos -  1, 15)] + buf[band(pos - 8, 15)])
			s1 = s1 + 0.025537501916464797 * (buf[band(pos -  2, 15)] + buf[band(pos - 7, 15)])
			s1 = s1 - 0.077656515457906181 * (buf[band(pos -  3, 15)] + buf[band(pos - 6, 15)])
			s1 = s1 + 0.307704571377828362 * (buf[band(pos -  4, 15)] + buf[band(pos - 5, 15)])
			-- stylua: ignore end

			local s2 = 0
			s2 = s2 + 0.5 * buf[band(pos - 4, 15)]

			return s1, s2
		end,
	}
end

return Upsampler
