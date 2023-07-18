require("include/protoplug")

stereoFx.init()

function stereoFx.Channel:init()
	self.b0 = 0.0
	self.b1 = 0.0
	self.b2 = 0.0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local white = 2 * (math.random() - 0.5)

		self.b0 = 0.99765 * self.b0 + white * 0.0990460
		self.b1 = 0.96300 * self.b1 + white * 0.2965164
		self.b2 = 0.57000 * self.b2 + white * 1.0526913
		local out = self.b0 + self.b1 + self.b2 + white * 0.1848

		samples[i] = out * 0.1
	end
end
