--[[
FIR 2x upsampler
kaiser window, beta = 8

optimized version
]]

local bit = require("bit")

local band = bit.band

local function Upsampler()
	local buf = ffi.new("double[?]", 32)

	local pos = 0

	return {
		tick = function(s)
			pos = band(pos + 1, 31)
			buf[pos] = 2 * s

			local s1 = 0
			-- stylua: ignore start
			s1 = s1 - 4.963152495408814014e-05 * (buf[pos]               + buf[band(pos - 15, 31)])
			s1 = s1 + 6.422753305175166617e-04 * (buf[band(pos - 1, 31)] + buf[band(pos - 14, 31)])
			s1 = s1 - 2.734532124792964612e-03 * (buf[band(pos - 2, 31)] + buf[band(pos - 13, 31)])
			s1 = s1 + 8.020590061657529093e-03 * (buf[band(pos - 3, 31)] + buf[band(pos - 12, 31)])
			s1 = s1 - 1.922827575230940181e-02 * (buf[band(pos - 4, 31)] + buf[band(pos - 11, 31)])
			s1 = s1 + 4.153808252109551791e-02 * (buf[band(pos - 5, 31)] + buf[band(pos - 10, 31)])
			s1 = s1 - 9.122783426324643230e-02 * (buf[band(pos - 6, 31)] + buf[band(pos -  9, 31)])
			s1 = s1 + 3.130559118266645346e-01 * (buf[band(pos - 7, 31)] + buf[band(pos -  8, 31)])
			-- stylua: ignore end

			local s2 = 0
			s2 = s2 + 0.5 * buf[band(pos - 7, 31)]

			return s1, s2
		end,
	}
end

return Upsampler
