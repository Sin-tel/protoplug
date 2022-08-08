local M = {}

function M.new(p)
	local params = p or { g = 0.5, r = 0.5, h = 0.5 }
	local s1_, s2_ = 0, 0
	local freq = 1

	local public = {
		update = function(f, invRes)
			f = math.min(0.49, f)

			freq = f
			params.g = math.tan(math.pi * f)

			params.r = 2 * invRes
			params.h = 1.0 / (1.0 + params.r * params.g + params.g * params.g)

			params.nlgain = 2.0
			params.gain = math.sqrt(params.nlgain)
			params.bias = 0.5 * freq
		end,

		process = function(input)
			input = input + 0.00001 * (math.random() - 0.5) + params.bias
			local hp, bp, lp

			-- nonlinear section
			s2_ = s2_ / (1 + params.nlgain * s2_ * s2_)
			s1_ = s1_ / (1 + params.nlgain * s1_ * s1_)

			-- s1_ = math.tanh(s1_ * params.nlgain) / params.nlgain
			-- s2_ = math.tanh(s2_ * params.nlgain) / params.nlgain

			-- antisaturator, bad stability
			-- local fb = params.r * s1_ + 5 * s1_ * math.abs(s1_)
			-- local a = 0.0
			-- local fb = params.r * (s1_ + math.atan(s1_))
			local fb = params.r * s1_

			-- filter update
			hp = (input - fb - params.g * s1_ - s2_) * params.h

			local v1 = params.g * hp
			bp = v1 + s1_
			s1_ = v1 + bp

			local v2 = params.g * bp
			lp = v2 + s2_
			s2_ = v2 + lp

			return params.gain * (lp - params.bias), params.gain * bp, params.gain * hp
		end,

		bpGain = function()
			return params.r
		end,
	}
	return public
end

return M
