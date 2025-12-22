require("include/protoplug")
local Polyphase = require("include/dsp/polyphase")

local COEFS

-- COEFS = {
-- 	0.07711508,
-- 	0.26596853,
-- 	0.48207062,
-- 	0.66510415,
-- 	0.79682046,
-- 	0.8841015,
-- 	0.94125146,
-- 	0.9820054,
-- }

COEFS = Polyphase.presets.coef_8

local prev = 0
local filter_odd = Polyphase.new(COEFS)
local filter_even = Polyphase.new(COEFS)
local odd = false

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[0][i]

		odd = not odd
		local u0, u1
		if odd then
			u0, u1 = filter_odd.process_sample(s, prev)
		else
			u0, u1 = filter_even.process_sample(s, prev)
		end
		prev = s

		local out = 0.5 * (u0 + u1)
		samples[0][i] = out
		samples[1][i] = out
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
