require("include/protoplug")
local Polyphase = require("include/dsp/polyphase")

local samplerate = 44100

local COEFS = Polyphase.presets.coef_12

stereoFx.init()

-- everything is per stereo channel
function stereoFx.Channel:init()
	self.phase = 0
	self.upsampler = Polyphase.new(COEFS)
	self.downsampler = Polyphase.new(COEFS)
end

function stereoFx.Channel:tick(u)
	return math.max(-1, math.min(1, u))
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		local u1, u2 = self.upsampler.upsample(s)

		u1 = self:tick(u1)
		u2 = self:tick(u2)

		local out = self.downsampler.downsample(u1, u2)

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "Freq",
		min = 1,
		max = 22000,
		changed = function(val)
			f = 2 * math.pi * val / samplerate
		end,
	},
})
