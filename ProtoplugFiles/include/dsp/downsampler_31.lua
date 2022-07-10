--[[
FIR 2x downsampler
31 taps
kaiser window, beta = 8

optimized version
]]

local bit = require("bit")

local band = bit.band

local function Downsampler()
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
			s = s - 4.963152495408814014e-05 * (buf[pos]                + buf[band(pos - 30, 31)])
			s = s + 6.422753305175166617e-04 * (buf[band(pos -  2, 31)] + buf[band(pos - 28, 31)])
			s = s - 2.734532124792964612e-03 * (buf[band(pos -  4, 31)] + buf[band(pos - 26, 31)])
			s = s + 8.020590061657529093e-03 * (buf[band(pos -  6, 31)] + buf[band(pos - 24, 31)])
			s = s - 1.922827575230940181e-02 * (buf[band(pos -  8, 31)] + buf[band(pos - 22, 31)])
			s = s + 4.153808252109551791e-02 * (buf[band(pos - 10, 31)] + buf[band(pos - 20, 31)])
			s = s - 9.122783426324643230e-02 * (buf[band(pos - 12, 31)] + buf[band(pos - 18, 31)])
			s = s + 3.130559118266645346e-01 * (buf[band(pos - 14, 31)] + buf[band(pos - 16, 31)])
			-- -- stylua: ignore end

			s = s + 0.5 * buf[band(pos - 15,31)]

			return s
		end,
	}
end

return Downsampler
