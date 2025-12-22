require("include/protoplug")
local cbFilter = require("include/dsp/cookbook_svf")

local noise_level = 0.5

stereoFx.init()
function stereoFx.Channel:init()
	self.post = cbFilter({ type = "tilt", f = 2000, gain = -12, Q = 0.7 })
	self.low = cbFilter({ type = "lp", f = 1200, gain = 0, Q = 0.7 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for k = 0, smax do
		local sample = samples[k]

		local dry = sample

		sample = self.low.process(sample)

		-- input-dependent noise
		local noise_a = (math.random() - 0.5) * noise_level * sample
		noise_a = self.post.process(noise_a)

		sample = dry + noise_a

		samples[k] = sample
	end
end

params = plugin.manageParams({
	{
		name = "noise",
		min = 0,
		max = 1,
		default = 0.5,
		changed = function(val)
			noise_level = val * val * 0.5
		end,
	},
})

--params.resetToDefaults()
