--[[
Drop-in replacement for cookbook filters with better behaviour and stability.

after Andrew Simper, Cytomic, 2013, andy@cytomic.comd
see: https://cytomic.com/files/dsp/SvfLinearTrapOptimised2.pdf
]]

local function Filter(args)
	local a1, a2, a3 = 0, 0, 0
	local m1, m2, m3 = 0, 0, 0
	local sample_rate = 44100
	local ic1eq = 0
	local ic2eq = 0
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

			local g = math.tan(math.pi * params.f / sample_rate)
			local k = 1.0 / params.Q
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

		process = function(v0)
			local v3 = v0 - ic2eq
			local v1 = a1 * ic1eq + a2 * v3
			local v2 = ic2eq + a2 * ic1eq + a3 * v3
			ic1eq = 2.0 * v1 - ic1eq
			ic2eq = 2.0 * v2 - ic2eq

			return m0 * v0 + m1 * v1 + m2 * v2
		end,
	}

	-- initialize when the samplerate in known
	plugin.addHandler("prepareToPlay", public.update)

	return public
end

return Filter
