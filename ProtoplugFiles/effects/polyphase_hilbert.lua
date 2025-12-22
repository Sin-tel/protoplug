require("include/protoplug")
local Polyphase = require("include/dsp/polyphase")

local prev = 0
local filter_odd = Polyphase.new(Polyphase.presets.coef_8)
local filter_even = Polyphase.new(Polyphase.presets.coef_8)
local odd = false

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[0][i]

		odd = not odd
		local u0, u1
		if odd then
			u0, u1 = filter_odd.process_sample_neg(s, prev)
		else
			u0, u1 = filter_even.process_sample_neg(s, prev)
		end
		prev = s

		samples[0][i] = u0
		samples[1][i] = u1
	end
end

-- params = plugin.manageParams({
-- 	{
-- 		name = "Freq",
-- 		min = 1,
-- 		max = 22000,
-- 		changed = function(val)
-- 			f = 2 * math.pi * val / samplerate
-- 		end,
-- 	},
-- })
