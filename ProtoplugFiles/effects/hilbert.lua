require("include/protoplug")
local Hilbert = require("include/dsp/hilbert")

local hilbert = Hilbert.new()

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[0][i]

		local u0, u1 = hilbert.process(s)

		samples[0][i] = u0
		samples[1][i] = u1
	end
end
