--[[
Sallen-Key filter

     y0       y1        
x->+---> [LP] -.-> [LP] -.-> y2
   ^           |         |
   |           v  (-)    |
   .-----<r|---+<--------.

Nonlinearities evaluated using Mystran's secant method

	We want to solve:
		y0 = tanh(x + tanh(r*(y1-y2)))
		dy1/dt = f * (     y0  - tanh(y1))
		dy2/dt = f * (tanh(y1) - tanh(y2))

	(tanh can be replaced by other nonlinearities)
	
	Trapezoidal integration + linearizing tanh(x0) as t0*x0 gives:
		y0 = t0 * (x + tk * r * (y1 - y2))
		y1 = s1 + f * (y0 - t1 * y1)
		y2 = s2 + f * (t1 * y1 - t2 * y2)

		s1 += 2 * f * (t0 * y0 - t1 * y1)
		s2 += 2 * f * (t1 * y1 - t2 * y2)

	Solving each:
		y0 = t0 * (x + tk * r * (y1 - y2))
		y1 = g1 * (s1 + f * y0)
		y2 = g2 * (s2 + f * t1 * y1)

		g1 = 1 / (1 + f*t1)
		g2 = 1 / (1 + f*t2)

	Maxima code:
	
	declare([s1,s2,x], mainvar);
		solve([
			y0 = t0 * (x + tk * r * (y1 - y2)),
			y1 = g1 * (s1 + f * y0),
			y2 = g2 * (s2 + f * t1 * y1)
		], [y0, y1, y2]);

	Then use the solve for y0.
]]

local M = {}

-- approximate tanh(x)/x
local function tanhdx(x)
	local a = x * x
	return ((a + 105) * a + 945) / ((15 * a + 420) * a + 945)
end

-- diode clipper feedback /x
local function distdx(x)
	local a = 0.135
	return a + (1 - a) / (math.sqrt(1 + 10 * x * x))
end

-- asymmetric input distortion /x
local function dist2dx(x)
	return 1 / (1 + math.abs(x) + 0.2 * x)
end

function M.new()
	local s1_, s2_ = 0, 0
	local f, r = 0, 0

	local public = {
		update = function(freq, res)
			freq = math.min(0.49, freq)

			f = math.tan(math.pi * freq)
			r = 2 * res
		end,

		process = function(x)
			-- evaluate the non-linear gains
			local tk = distdx(r * (s1_ - s2_)) -- feedback
			local t0 = dist2dx(x + r * (s1_ - s2_)) -- input
			local t1 = tanhdx(s1_) -- integrators
			local t2 = tanhdx(s2_)

			-- feedback gains
			local g1 = 1 / (1 + f * t1)
			local g2 = 1 / (1 + f * t2)

			-- solve for y0
			local y0 = (t0 * x + r * t0 * tk * (g1 * s1_ * (1.0 - f * g2 * t1) - g2 * s2_))
				/ (t0 * tk * r * g1 * (f * f * g2 * t1 - f) + 1.0)

			-- slightly less efficient version
			-- local y1 = g1 * (s1_ + f * y0)
			-- local y2 = g2 * (s2_ + f * t1 * y1)
			-- s1_ = s1_ + 2 * f * (t0 * y0 - t1 * y1)
			-- s2_ = s2_ + 2 * f * (t1 * y1 - t2 * y2)

			-- solve remaining outputs
			local y1 = t1 * g1 * (s1_ + f * y0)
			local y2 = t2 * g2 * (s2_ + f * y1)

			-- -- update state
			s1_ = s1_ + 2 * f * (t0 * y0 - y1)
			s2_ = s2_ + 2 * f * (y1 - y2)

			-- lowpass
			return y2

			-- bandpass
			-- return y1 - y2

			-- highpass
			-- return y0 - 2 * y1 + y2
		end,
	}
	return public
end

return M
