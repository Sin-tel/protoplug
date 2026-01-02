local Polyphase = require("include/dsp/polyphase")

local Hilbert = {}

function Hilbert.new()
	local prev = 0
	local filter_odd = Polyphase.new(Polyphase.presets.coef_12)
	local filter_even = Polyphase.new(Polyphase.presets.coef_12)
	local odd = false
	return {
		process = function(s)
			odd = not odd
			local u0, u1
			if odd then
				u0, u1 = filter_odd.process_sample_neg(s, prev)
			else
				u0, u1 = filter_even.process_sample_neg(s, prev)
			end
			prev = s

			return u0, u1
		end,
	}
end

return Hilbert
