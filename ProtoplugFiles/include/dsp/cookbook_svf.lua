--[[
Drop-in replacement for cookbook filters with better behaviour and stability.

after Andrew Simper, Cytomic, 2013, andy@cytomic.comd
see: https://cytomic.com/files/dsp/SvfLinearTrapOptimised2.pdf
]]

local function Filter(args)
	local a1, a2, a3 = 0, 0, 0
	local m0, m1, m2 = 0, 0, 0
	local g, k = 0, 0
	local sample_rate = 44100
	local ic1eq = 0
	local ic2eq = 0
	local params = { type = "lp", f = 440, gain = 0, Q = 1, oversample = 1 }
	args = args or {}
	for l, v in pairs(args) do
		params[l] = v
	end

	local public = {
		update = function(args)
			args = args or {}
			for l, v in pairs(args) do
				params[l] = v
			end

			if not plugin.isSampleRateKnown() then
				return
			end

			sample_rate = plugin.getSampleRate() * params.oversample

			local ff = params.f / sample_rate
			ff = math.min(ff, 0.49)

			g = math.tan(math.pi * ff)
			k = 1.0 / params.Q
			local a = math.pow(10, params.gain / 40)
			if params.type == "lp" then
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = 0.0
				m1 = 0.0
				m2 = 1.0
			elseif params.type == "bp" then
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = 0.0
				m1 = 1.0
				m2 = 0.0
			elseif params.type == "bpc" then
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = 0.0
				m1 = k
				m2 = 0.0
			elseif params.type == "hp" then
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = 1.0
				m1 = -k
				m2 = -1.0
			elseif params.type == "bs" then
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = 1.0
				m1 = -k
				m2 = 0.0
			elseif params.type == "ap" then
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = 1.0
				m1 = -2.0 * k
				m2 = 0.0
			elseif params.type == "ls" then
				g = g / math.sqrt(a)
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = 1.0
				m1 = k * (a - 1.0)
				m2 = a * a - 1.0
			elseif params.type == "hs" then
				g = g * math.sqrt(a)
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = a * a
				m1 = k * (1.0 - a) * a
				m2 = 1.0 - a * a
			elseif params.type == "tilt" then
				g = g * math.sqrt(a)
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = a
				m1 = k * (1.0 - a)
				m2 = 1.0 / a - a
			elseif params.type == "eq" then
				k = 1.0 / (params.Q * a)
				a1 = 1.0 / (1.0 + g * (g + k))
				a2 = g * a1
				a3 = g * a2
				m0 = 1.0
				m1 = k * (a * a - 1.0)
				m2 = 0.0
			else
				error("Unsupported filter type " .. params.type)
			end
		end,

		reset_state = function()
			ic1eq = 0
			ic2eq = 0
		end,

		process = function(v0)
			local v3 = v0 - ic2eq
			local v1 = a1 * ic1eq + a2 * v3
			local v2 = ic2eq + a2 * ic1eq + a3 * v3
			ic1eq = 2.0 * v1 - ic1eq
			ic2eq = 2.0 * v2 - ic2eq

			return m0 * v0 + m1 * v1 + m2 * v2
		end,

		phaseDelay = function(frequency)
			local g2 = g * g

			local d0 = 1. + g2 + g * k
			local d1 = -2. + 2. * g2
			local d2 = 1. + g2 - g * k

			local n0 = m0 * d0 + m1 * g + m2 * g2
			local n1 = m0 * d1 + m2 * 2. * g2
			local n2 = m0 * d2 - m1 * g + m2 * g2

			local omega = 2 * math.pi * frequency / plugin.getSampleRate()

			local c1 = math.cos(-omega)
			local s1 = math.sin(-omega)

			local c2 = math.cos(-2 * omega)
			local s2 = math.sin(-2 * omega)

			local real = n0 + n1 * c1 + n2 * c2
			local imag = n1 * s1 + n2 * s2

			local phase = math.atan2(imag, real)

			real = d0 + d1 * c1 + d2 * c2
			imag = d1 * s1 + d2 * s2

			phase = phase - math.atan2(imag, real)
			-- phase = math.fmod(-phase, 2 * math.pi)
			phase = (math.pi - phase) % (2 * math.pi) - math.pi
			return phase / omega
		end,
	}

	-- initialize when the samplerate in known
	plugin.addHandler("prepareToPlay", public.update)

	return public
end

return Filter
