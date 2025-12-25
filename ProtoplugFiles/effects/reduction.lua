-- Sample rate reduction
require("include/protoplug")

local Polyphase = require("include/dsp/polyphase")
local COEFS = Polyphase.presets.coef_12

local target_rate = 0.

local sample_rate = 4410

plugin.addHandler("prepareToPlay", function()
	sample_rate = plugin.getSampleRate()
end)

stereoFx.init()
function stereoFx.Channel:init()
	self.accum = 0.
	self.s = 0.
	self.prev = 0.

	self.upsampler = Polyphase.new(COEFS)
	self.downsampler = Polyphase.new(COEFS)
end

function stereoFx.Channel:tick(x)
	local step = target_rate / (2 * sample_rate)

	self.accum = self.accum + step

	-- output held sample if nothing happens
	local out = self.s

	if self.accum > 1.0 then
		self.accum = self.accum - 1.0

		-- linear interpolation on input
		local a = self.accum / step
		local s = self.prev * a + x * (1.0 - a)

		local next_s = s

		-- linear interpolation on output
		local b = (step - self.accum) / step
		out = self.s * b + next_s * (1.0 - b)

		self.s = next_s
	end
	self.prev = x

	return out
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
		name = "Rate",
		min = 20,
		max = 40000,
		default = 1400,
		changed = function(val)
			target_rate = val
		end,
	},
})

params.resetToDefaults()
