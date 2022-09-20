--[[
nonlinear version

system:
	y0 = x - atanh(k*y1) - y2
	dy1/dt = f * tanh(y0)
	dy2/dt = f * tanh(y1)
discretize (tk replaces k)
	y0 = x - tk*y1 - y2
	y1 = s1 + f * t0*y0
	y2 = s2 + f * t1*y1

	s1 = s1 + 2 * f * t0*y0
	s2 = s2 + 2 * f * t1*y1

maxima code: 

declare([s1,s2,x], mainvar);
		solve([
			y0 = x - k*y1 - y2,
			y1 = s1 + f * t0*y0,
			y2 = s2 + f * t1*y1
		], [y0, y1, y2]);

use solve for y1, etc
]]

-- approximate tanh(x)/x
local function tanhdx(x)
	local a = x * x
	return ((a + 105) * a + 945) / ((15 * a + 420) * a + 945)
end

-- asymmetric input distortion /x
local function dist2dx(x)
	return 1 / (1 + math.abs(x) + 0.2 * x)
end

local function Filter(args)
	local g = 0
	---local g1 = 0
	local k = 0
	local m0, m1, m2 = 0, 0, 0
	local sample_rate = 44100
	local s1_ = 0
	local s2_ = 0
	local params = { type = "lp", f = 440, gain = 0, Q = 1 }
	args = args or {}
	for k, v in pairs(args) do
		params[k] = v
	end

	public = {
		update = function(args)
			args = args or {}
			for k, v in pairs(args) do
				params[k] = v
			end

			if not plugin.isSampleRateKnown() then
				return
			end

			sample_rate = plugin.getSampleRate()

			g = math.tan(math.pi * params.f / sample_rate)
			k = 1.0 / params.Q
			local a = math.pow(10, params.gain / 40)
			if params.type == "lp" then
				m0 = 0.0
				m1 = 0.0
				m2 = 1.0
			elseif params.type == "bp" then
				m0 = 0.0
				m1 = 1.0
				m2 = 0.0
			elseif params.type == "bpc" then
				m0 = 0.0
				m1 = k
				m2 = 0.0
			elseif params.type == "hp" then
				m0 = 1.0
				m1 = -k
				m2 = -1.0
			elseif params.type == "bs" then
				m0 = 1.0
				m1 = -k
				m2 = 0.0
			elseif params.type == "ap" then
				m0 = 1.0
				m1 = -2.0 * k
				m2 = 0.0
			elseif params.type == "ls" then
				g = g / math.sqrt(a)
				m0 = 1.0
				m1 = k * (a - 1.0)
				m2 = a * a - 1.0
			elseif params.type == "hs" then
				g = g * math.sqrt(a)
				m0 = a * a
				m1 = k * (1.0 - a) * a
				m2 = 1.0 - a * a
			elseif params.type == "tilt" then
				g = g * math.sqrt(a)
				m0 = a
				m1 = k * (1.0 - a)
				m2 = 1.0 / a - a
			elseif params.type == "eq" then
				k = 1.0 / (params.Q * a)
				m0 = 1.0
				m1 = k * (a * a - 1.0)
				m2 = 0.0
			else
				error("Unsupported filter type " .. params.type)
			end
		end,

		process = function(x)
			local tk = k + 0.2 * s1_ * s1_ -- cubic distortion
			local t0 = tanhdx(x - tk * s1_ - s2_)
			local t1 = tanhdx(s1_)

			-- solve for y1
			local y1 = (g * t0 * (x - s2_) + s1_) / (g * t0 * (tk + g * t1) + 1)
			-- solve remaining
			local y2 = s2_ + g * t1 * y1
			local y0 = x - tk * y1 - y2

			-- update integrators
			s1_ = s1_ + 2.0 * g * t0 * y0
			s2_ = s2_ + 2.0 * g * t1 * y1

			local out = m0 * x + m1 * t1 * y1 + m2 * y2

			return out
		end,
	}

	-- initialize when the samplerate in known
	plugin.addHandler("prepareToPlay", public.update)

	return public
end

return Filter
