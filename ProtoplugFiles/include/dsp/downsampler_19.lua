--[[
FIR 2x downsampler
19 taps
kaiser window, beta = 6

optimized version
]]

local bit = require("bit")

local band = bit.band

function Downsampler()
	local buf = ffi.new("double[?]", 32)

	local pos = 0

	return {
		tick = function(s1, s2)
			pos = band(pos + 1, 31)
			buf[pos] = s1
			pos = band(pos + 1, 31)
			buf[pos] = s2

			local s = 0
			-- stylua: ignore start
			s = s + 0.000526036693443370 * (buf[pos]                + buf[band(pos - 18, 31)])
			s = s - 0.006280266471956432 * (buf[band(pos -  2, 31)] + buf[band(pos - 16, 31)])
			s = s + 0.025537501916464797 * (buf[band(pos -  4, 31)] + buf[band(pos - 14, 31)])
			s = s - 0.077656515457906181 * (buf[band(pos -  6, 31)] + buf[band(pos - 12, 31)])
			s = s + 0.307704571377828362 * (buf[band(pos -  8, 31)] + buf[band(pos - 10, 31)])
			-- -- stylua: ignore end

			s = s + 0.5 * buf[band(pos - 9,31)]

			return s
		end,
	}
end

return Downsampler
