require("include/protoplug")

local Polyphase = require("include/dsp/polyphase")
local Filter = require("include/dsp/cookbook_svf")

local COEFS = Polyphase.presets.coef_8

-- parameter state
local target_rate = 4000
local jitter_amount = 0.0
local use_pre_filter = false
local use_post_filter = false

-- global dsp state
local sample_rate = 44100
local inv_2sr = 1.0 / 88200

plugin.addHandler("prepareToPlay", function()
	sample_rate = plugin.getSampleRate()
	inv_2sr = 1.0 / (2.0 * sample_rate)
end)

local function update_filters()
	stereoFx.LChannel:update_filters()
	stereoFx.RChannel:update_filters()
end

stereoFx.init()
function stereoFx.Channel:init()
	self.is_init = true

	self.accum = 0.
	self.s = 0.
	self.prev = 0.

	self.jitter = 1.0

	self.upsampler = Polyphase.new(COEFS)
	self.downsampler = Polyphase.new(COEFS)

	-- butterworth cascades
	self.pre_lp1 = Filter({ type = "lp", f = 2000, Q = 0.5412 })
	self.pre_lp2 = Filter({ type = "lp", f = 2000, Q = 1.3066 })

	self.post_lp1 = Filter({ type = "lp", f = 2000, Q = 0.5412 })
	self.post_lp2 = Filter({ type = "lp", f = 2000, Q = 1.3066 })
end

function stereoFx.Channel:update_filters()
	if not self.is_init then
		return
	end
	local cutoff = target_rate * 0.5
	self.pre_lp1.update({ f = cutoff })
	self.pre_lp2.update({ f = cutoff })
	self.post_lp1.update({ f = cutoff })
	self.post_lp2.update({ f = cutoff })
end

function stereoFx.Channel:tick(x)
	local step = target_rate * inv_2sr * self.jitter

	self.accum = self.accum + step

	local out = self.s

	while self.accum >= 1.0 do
		self.accum = self.accum - 1.0

		local a = self.accum / step

		-- linear interpolation on input
		local next_s = x * (1.0 - a) + self.prev * a

		-- linear interpolation on output
		out = self.s * (1.0 - a) + next_s * a

		self.s = next_s

		if jitter_amount > 0 then
			local noise = math.random() - 0.5
			self.jitter = 1.0 + (noise * jitter_amount)
		else
			self.jitter = 1.0
		end
	end

	self.prev = x
	return out
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		if use_pre_filter then
			s = self.pre_lp1.process(s)
			s = self.pre_lp2.process(s)
		end

		local u1, u2 = self.upsampler.upsample(s)
		u1 = self:tick(u1)
		u2 = self:tick(u2)
		local out = self.downsampler.downsample(u1, u2)

		if use_post_filter then
			out = self.post_lp1.process(out)
			out = self.post_lp2.process(out)
		end

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "Rate",
		min = 100,
		max = 20000,
		default = 4000,
		changed = function(val)
			target_rate = val
			update_filters()
		end,
	},
	{
		name = "Jitter",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			jitter_amount = 0.8 * val * val
		end,
	},
	{
		name = "Pre Filter",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			use_pre_filter = (val > 0.5)
		end,
	},
	{
		name = "Post Filter",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			use_post_filter = (val > 0.5)
		end,
	},
})

-- params.resetToDefaults()
