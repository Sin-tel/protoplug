-- LR to MS (or vice versa!)

require("include/protoplug")

local INV_SQRT = 0.707106781187

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local in_l = samples[0][i]
		local in_r = samples[1][i]

		samples[0][i] = (in_l + in_r) * INV_SQRT
		samples[1][i] = (in_l - in_r) * INV_SQRT
	end
end
