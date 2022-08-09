-- Sallen-Key filter with nonlinearity

local M = {}

-- cheap non-symmetric distortion
local function dist(x)
	return x / (1 + math.abs(x) + 0.4 * x)
end

function M.new()
	local params = {}
	local s1_, s2_ = 0, 0
	local freq = 1
	local a0, a1, a2, a3, a4, a5 = 0, 0, 0, 0, 0, 0

	local public = {
		update = function(f, res)
			f = math.min(0.49, f)

			freq = f
			params.g = math.tan(math.pi * f)
			params.k = 2 * res

			a0 = params.g / (1.0 + params.g)
			a1 = 1.0 / (1.0 + params.g)
			a2 = a0 * a1
			a3 = a1 * a1
		end,

		process = function(x)
			-- instantaneous response
			local G = a2
			local S = a3 * s1_ - a1 * s2_

			-- feedback eqn
			local u = (x + params.k * S) / (1 - params.k * G)

			-- distortion in feedback
			u = x + params.k * dist(G * u + S)

			-- distortion in filter input
			u = dist(u * 0.5) * 2

			-- update
			-- one pole LP
			local v1 = (u - s1_) * a0
			local v2 = v1 + s1_
			s1_ = v2 + v1
			-- one pole LP
			local v3 = (v2 - s2_) * a0
			local v4 = v3 + s2_
			s2_ = v4 + v3

			-- lowpass
			return v4

			-- bandpass
			-- return v2 - v4

			-- highpass
			-- return u - 2 * v2 + v4
		end,
	}
	return public
end

return M
