function Svf(params)
	local params = params or {g = 0.5, r = 0.5, h = 0.5}
	local s1_, s2_ = 0,0
	local freq = 1

	public = {
		update = function (f,res)
			--if f >= 0.49 then f = 0.49 end
			f = math.min(0.49, f)

			freq = f
			params.g = math.tan(math.pi*f)

			params.r = 2*res
			params.h = 1.0 / (1.0 + params.r * params.g + params.g * params.g)
		end;
		
		process = function (input)
			local hp, bp, lp
			hp = (input - (params.r + params.g) * s1_ - s2_) * params.h

			local v1 = params.g * hp
			--bp = math.tanh(v1 + s1_)
		    bp = v1 + s1_
			s1_ = v1 + bp
			
			s1_ = math.tanh(2*s1_)/2

			local v2 = params.g * bp
			
			--lp = math.tanh(v2 + s2_)
			lp = v2 + s2_
			s2_ = v2 + lp
			
			--s2_ = math.tanh(s2_)

			return lp, bp, hp
		end;

		bpGain = function ()
			return params.r
		end;
	}
	return public
end