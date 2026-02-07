local Polyphase = require("include/dsp/polyphase")

local Hilbert = {}

local coefs = {
	0.16177742,
	0.4794411,
	0.7330669,
	0.8762436,
	0.94536304,
	0.976603,
	0.9906005,
	0.9974994,
}

function Hilbert.new()
	local prev = 0
	local filter_odd = Polyphase.new(coefs)
	local filter_even = Polyphase.new(coefs)
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
