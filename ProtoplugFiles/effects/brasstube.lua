-- brass tube with variable speed of sound due to pressure

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local lp2filters = {}

local len = 760

local beta = 0.01

local line = {}
for i = 1, len do
	line[i] = 0
end
local line2 = {}
for i = 1, len do
	line[i] = 0
end

local high = cbFilter({ type = "hp", f = 20, gain = 0, Q = 0.7 })

local lp2 = cbFilter({
	type = "lp",
	f = 12000,
	gain = 0,
	Q = 0.707,
})

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local input = samples[0][i]

		local feedback = high.process(line[len - 1])
		feedback = lp2.process(feedback) * 0.75

		local s = input + feedback
		s = math.max(math.min(s, 1), -1)

		line2[1] = s
		line[0] = s
		for i = 2, len do
			local e = beta * (0.5 + 0.5 * line[i - 1])
			--e = math.max(math.min(e,1),0)

			line2[i] = (1 - e) * line[i - 1] + e * line[i - 2]
		end

		--swap buffers
		line, line2 = line2, line

		local signal = line[math.floor(len / 2)]

		samples[0][i] = signal
		samples[1][i] = signal
	end
end

params = plugin.manageParams({

	{
		name = "Cutoff",
		min = 0,
		max = 10,
		changed = function(val)
			lp2.update({ f = 22000 * math.exp(val - 10) })
		end,
	},
})
