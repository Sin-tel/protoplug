-- 4 pole ladder filter

local M = {}

local function dist(x)
	return math.log(x + math.sqrt(1 + x * x))
end

-- cheap non-symmetric distortion
local function dist2(x)
	return x / (1 + math.abs(x) + 0.4 * x)
end

function M.new()
	local params = {}
	local s1_, s2_, s3_, s4_ = 0, 0, 0, 0
	local freq = 1
	local a0, a1 = 0, 0

	local prev = 0

	local public = {
		update = function(f, res)
			f = math.min(0.49, f)

			freq = f
			params.g = math.tan(math.pi * f)
			params.k = 4 * res

			a0 = params.g / (1.0 + params.g)
			a1 = 1.0 / (1.0 + params.g)
		end,

		process = function(x)
			-- instantaneous response
			local G = a0 ^ 4
			local S = a0 * a0 * a0 * a1 * s1_ + a0 * a0 * a1 * s2_ + a0 * a1 * s3_ + a1 * s4_

			-- compensate gain
			x = x * (1 + params.k)

			-- feedback eqn
			local u = (x - params.k * S) / (1 + params.k * G)

			-- fixed point iter
			u = x - params.k * (G * dist2(u) + S)
			u = x - params.k * (G * dist2(u) + S)

			-- update
			u = dist2(u)

			local v1 = (u - s1_) * a0
			local y1 = v1 + s1_
			s1_ = y1 + v1

			local v2 = (y1 - s2_) * a0
			local y2 = v2 + s2_
			s2_ = y2 + v2

			local v3 = (y2 - s3_) * a0
			local y3 = v3 + s3_
			s3_ = y3 + v3

			local v4 = (y3 - s4_) * a0
			local y4 = v4 + s4_
			s4_ = y4 + v4

			-- lowpass
			return y4
		end,
	}
	return public
end

return M
