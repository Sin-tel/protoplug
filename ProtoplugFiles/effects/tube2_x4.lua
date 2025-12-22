require("include/protoplug")
local Downsampler19 = require("include/dsp/downsampler_19")
local Downsampler31 = require("include/dsp/downsampler_31")
local Downsampler59 = require("include/dsp/downsampler_59")
local Upsampler11 = require("include/dsp/upsampler_11")
local Upsampler19 = require("include/dsp/upsampler_19")
local Upsampler31 = require("include/dsp/upsampler_31")
local cbFilter = require("include/dsp/cookbook_svf")

local Delay = require("include/dsp/fdelay_line")

local a = 0
local b = 0
local balance = 1
local bias = 0.4

stereoFx.init()

local function softclip(x)
	local s = math.max(math.min(x, 3), -3)
	return s * (27 + s * s) / (27 + 9 * s * s)
end

-- everything is per stereo channel
function stereoFx.Channel:init()
	self.phase = 0
	self.upsampler = Upsampler31()
	self.upsampler2 = Upsampler19()
	self.downsampler = Downsampler59()
	self.downsampler2 = Downsampler31()

	self.dry_delay = Delay(32)

	self.high = cbFilter({ type = "hp", f = 16, gain = 0, Q = 0.7 })

	self.low = cbFilter({ type = "lp", f = 6, gain = 0, Q = 0.7 })
	self.low2 = cbFilter({ type = "lp", f = 400, gain = 0, Q = 0.5 })

	self.pre = cbFilter({ type = "tilt", f = 300, gain = 3, Q = 0.4 })
	self.post = cbFilter({ type = "tilt", f = 300, gain = -3, Q = 0.4 })
end

function stereoFx.Channel:tick(u, w)
	u = u - 2 * bias * (1 - 2 * w)
	local s = math.max(u, 0)
	local z = u + s ^ 4

	return softclip(z)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		self.dry_delay.push(s)

		-- oversampling delay
		local dry = self.dry_delay.goBack_int(26)

		s = self.pre.process(s) * a

		-- this should really be happening in the oversampled part, but luajit chokes out if I try
		local w = self.low2.process(s)
		w = math.max(w, 0)
		w = self.low.process(w)

		local u1, u2 = self.upsampler.tick(s)

		local t1, t2 = self.upsampler2.tick(u1)
		local t3, t4 = self.upsampler2.tick(u2)

		t1 = self:tick(t1, w)
		t2 = self:tick(t2, w)
		t3 = self:tick(t3, w)
		t4 = self:tick(t4, w)

		local out = self.downsampler.tick(self.downsampler2.tick(t1, t2), self.downsampler2.tick(t3, t4))

		out = self.post.process(out)
		out = out * b / a
		out = self.high.process(out)

		samples[i] = (1.0 - balance) * dry + balance * out
	end
end

params = plugin.manageParams({
	{
		name = "dry/wet",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "drive",
		min = -12,
		max = 36,
		default = 0,
		changed = function(val)
			a = math.pow(10, val / 20)
		end,
	},
	{
		name = "bias",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			bias = val * 0.4
		end,
	},
	{
		name = "output",
		min = 0,
		max = 12,
		default = 0,
		changed = function(val)
			b = math.pow(10, val / 20)
		end,
	},
})

params.resetToDefaults()
