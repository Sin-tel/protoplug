-- nonlinear allpass

local M = {}

function M.new(gain)
	local s_ = 0
	local g = gain

	local public = {
		update = function(gain)
			g = gain
		end,

		process = function(x)
			local c = math.cos(g * x)
			local s = math.sin(g * x)

			local u = c * x - s * s_
			local y = s * x + c * s_

			s_ = u

			return y
		end,
	}
	return public
end

return M
