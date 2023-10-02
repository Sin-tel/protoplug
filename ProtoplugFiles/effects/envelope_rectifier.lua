require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

stereoFx.init()
function stereoFx.Channel:init()
	self.low = cbFilter({ type = "lp", f = 200, gain = 0, Q = 0.7 })
	self.high = cbFilter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local x = samples[i]
		-- half wave rectification
		x = math.max(0, x)
		x = self.low.process(x)

		-- higpass is just to kill DC
		x = self.high.process(x)

		samples[i] = x * 2
	end
end
