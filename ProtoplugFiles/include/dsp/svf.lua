-- see: Vadim Zavalishin, The Art of VA Filter Design. p. 110

local M = {}

function M.new(params)
	local params = params or { g = 0.5, r = 0.5, h = 0.5 }
	local s1_, s2_ = 0, 0
	local freq = 1

	local public = {
		update = function(f, invRes)
			f = math.min(0.49, f)

			freq = f
			params.g = math.tan(math.pi * f)

			params.r = 2 * invRes -- 2R
			params.h = 1.0 / (1.0 + params.r * params.g + params.g * params.g)
		end,

		process = function(input)
			local hp, bp, lp
			hp = (input - (params.r + params.g) * s1_ - s2_) * params.h

			local v1 = params.g * hp
			bp = v1 + s1_
			s1_ = v1 + bp

			local v2 = params.g * bp
			lp = v2 + s2_
			s2_ = v2 + lp

			return lp, bp, hp
		end,

		bpGain = function()
			return params.r
		end,
	}
	return public
end

return M
