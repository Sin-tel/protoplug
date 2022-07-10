--[[
Hilbert filter

coefficients are:
	0 for n even
	2 / (pi * n) for n odd
]]

local bit = require("bit")

local band = bit.band

local function hilbert()
	local buf = ffi.new("double[?]", 32)

	local pos = 0

	return {
		process = function(s)
			pos = band(pos + 1, 31)
			buf[pos] = s

			local l = 0
			-- stylua: ignore start
			l = l - 0.042441318157839 * (buf[pos]                - buf[band(pos - 30, 31)])
			l = l - 0.048970751720583 * (buf[band(pos -  2, 31)] - buf[band(pos - 28, 31)])
			l = l - 0.057874524760689 * (buf[band(pos -  4, 31)] - buf[band(pos - 26, 31)])
			l = l - 0.070735530263065 * (buf[band(pos -  6, 31)] - buf[band(pos - 24, 31)])
			l = l - 0.090945681766797 * (buf[band(pos -  8, 31)] - buf[band(pos - 22, 31)])
			l = l - 0.127323954473516 * (buf[band(pos - 10, 31)] - buf[band(pos - 20, 31)])
			l = l - 0.212206590789194 * (buf[band(pos - 12, 31)] - buf[band(pos - 18, 31)])
			l = l - 0.636619772367581 * (buf[band(pos - 14, 31)] - buf[band(pos - 16, 31)])
			-- -- stylua: ignore end

			local r =  buf[band(pos - 15,31)]

			return r, l
		end,
	}
end

return hilbert
