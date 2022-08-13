-- Multimode Sallen-Key filter with nonlinearity
-- LP -> HP
-- nonlinearity evaluated using the 'cheap' method + fixed point iteration

local M = {}

-- cheap non-symmetric distortion
local function dist2(x)
	return x / (1 + math.abs(x) + 0.4 * x)
end

local function hardclip(x)
	return math.min(math.max(x, -1.0), 1.0)
end

-- curve approximating feedback path in MS20
local function dist(x)
	local v = 5 * x
	v = v / math.sqrt(1 + v * v)
	local a = 0.135
	return a * x + (1 - a) * v / 5
end

local function dist3(x)
	return math.tanh(x + 0.3 * math.abs(x))
end

local function crossover(x)
	return math.tanh(x - math.tanh(50 * x) / 50)
end

function M.new()
	local params = {}
	local s1_, s2_ = 0, 0
	local freq = 1
	local a0, a1, a2, a3 = 0, 0, 0, 0

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
			u = x + dist(params.k * (G * u + S))

			-- fixed point iter
			u = x + params.k * (G * dist2(u) + S)
			u = x + params.k * (G * dist2(u) + S)

			-- update
			u = dist2(u)

			-- one pole LP
			local v1 = (u - s1_) * a0
			local y1 = v1 + s1_
			s1_ = y1 + v1

			-- one pole LP
			local v2 = (y1 - s2_) * a0
			local y2 = v2 + s2_
			s2_ = y2 + v2

			-- lowpass
			return y2

			-- bandpass
			-- return y1 - y2

			-- highpass
			-- return u - 2 * y1 + y2
		end,
	}
	return public
end

return M
