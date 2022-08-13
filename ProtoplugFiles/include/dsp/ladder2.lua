---- LICENSE TERMS: Copyright 2012 Teemu Voipio
--
-- You can use this however you like for pretty much any purpose,
-- as long as you don't claim you wrote it. There is no warranty.
--
-- Distribution of substantial portions of this code in source form
-- must include this copyright notice and list of conditions.
--

-- 4 pole ladder filter
-- Mystran's cheap method
-- see: https://www.kvraudio.com/forum/viewtopic.php?f=33&t=349859
-- I'm skipping the half-sample delay thing here

local M = {}

-- approximate tanh(x)/x
local function tanhXdX(x)
	local a = x * (x + 0.3) -- + 0.3 adds asymmetry
	return ((a + 105) * a + 945) / ((15 * a + 420) * a + 945)
end

function M.new()
	local s1_, s2_, s3_, s4_ = 0, 0, 0, 0
	local f, r = 0, 0

	local public = {
		update = function(freq, res)
			freq = math.min(0.49, freq)

			f = math.tan(math.pi * freq)
			r = 4 * res
		end,

		process = function(x)
			-- compensate gain
			x = x * (1 + r)

			-- evaluate the non-linear gains
			local t0 = tanhXdX(x - r * s4_)
			local t1 = tanhXdX(s1_)
			local t2 = tanhXdX(s2_)
			local t3 = tanhXdX(s3_)
			local t4 = tanhXdX(s4_)

			-- g# the denominators for solutions of individual stages
			local g1 = 1 / (1 + f * t1)
			local g2 = 1 / (1 + f * t2)
			local g3 = 1 / (1 + f * t3)
			local g4 = 1 / (1 + f * t4)

			-- f# are just factored out of the feedback solution
			local f3 = f * t3 * g4
			local f2 = f * t2 * g3 * f3
			local f1 = f * t1 * g2 * f2
			local f0 = f * t0 * g1 * f1

			-- solve feedback
			local y4 = (g4 * s4_ + f3 * g3 * s3_ + f2 * g2 * s2_ + f1 * g1 * s1_ + f0 * x) / (1 + r * f0)

			-- then solve the remaining outputs
			-- nonlinear gains are absorbed so y0 is actually t0*y0 etc.
			local y0 = t0 * (x - r * y4)
			local y1 = t1 * g1 * (s1_ + f * y0)
			local y2 = t2 * g2 * (s2_ + f * y1)
			local y3 = t3 * g3 * (s3_ + f * y2)

			-- update state
			s1_ = s1_ + 2 * f * (y0 - y1)
			s2_ = s2_ + 2 * f * (y1 - y2)
			s3_ = s3_ + 2 * f * (y2 - y3)
			s4_ = s4_ + 2 * f * (y3 - t4 * y4)

			return y4

			-- return y4 * (1 + r) --gain compensated
		end,
	}
	return public
end

return M
