require("include/protoplug")

local b0, b1, b2, b3 = 0.049922035, -0.095993537, 0.050612699, -0.004408786
local a1, a2, a3 = -2.494956002, 2.017265875, -0.522189400

stereoFx.init()

-- everything is per stereo channel
function stereoFx.Channel:init()
	self.x0 = 0
	self.x1 = 0
	self.x2 = 0
	self.x3 = 0

	self.y0 = 0
	self.y1 = 0
	self.y2 = 0
	self.y3 = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		self.x0 = 2 * (math.random() - 0.5)

		self.y3, self.y2, self.y1 = self.y2, self.y1, self.y0

		self.y0 = b0 * self.x0 + b1 * self.x1 + b2 * self.x2 + b3 * self.x3 - a1 * self.y1 - a2 * self.y2 - a3 * self.y3
		self.x3, self.x2, self.x1 = self.x2, self.x1, self.x0

		local out = self.y0

		samples[i] = out
	end
end
