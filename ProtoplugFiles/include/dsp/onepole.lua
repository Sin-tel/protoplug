local function Filter(args)
	local g = 0
	local mx, my = 0, 0

	local sample_rate = 44100
	local s = 0

	local params = { type = "lp", f = 440, gain = 0, oversample = 1 }
	args = args or {}
	for l, v in pairs(args) do
		params[l] = v
	end

	local public = {
		update = function(args2)
			args2 = args2 or {}
			for l, v in pairs(args2) do
				params[l] = v
			end

			if not plugin.isSampleRateKnown() then
				return
			end

			sample_rate = plugin.getSampleRate() * params.oversample

			local ff = params.f / sample_rate
			ff = math.min(ff, 0.49)

			local f = math.tan(math.pi * ff)
			g = f / (1 + f)
			local a = math.pow(10, params.gain / 40)

			if params.type == "lp" then
				my = 1
				mx = 0
			elseif params.type == "hp" then
				my = -1
				mx = 1
			elseif params.type == "ap" then
				my = 2
				mx = -1
			elseif params.type == "ls" then
				my = a * a - 1
				mx = 1
			elseif params.type == "hs" then
				my = 1 - a * a
				mx = a * a
			elseif params.type == "tilt" then
				my = (1 / a) - a
				mx = a
			else
				error("Unsupported filter type " .. params.type)
			end
		end,

		reset_state = function()
			s = 0
		end,

		process = function(x)
			local v = (x - s) * g
			local y = v + s
			s = y + v

			return mx * x + my * y
		end,
	}

	-- initialize when the samplerate in known
	plugin.addHandler("prepareToPlay", public.update)

	return public
end

return Filter
