require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local Upsampler = require("include/dsp/upsampler_11")
local Downsampler = require("include/dsp/downsampler_31")

local slew = 0.1
local mix = 1
local gain = 1

slew2 = 0.1

local db_to_exp = math.log(10) / 20

noise_level = 0.3

stereoFx.init()
function stereoFx.Channel:init()
	self.state = 0
	self.upsampler = Upsampler()
	self.downsampler = Downsampler()
end

local function dist(x)
	--return x / (1 + math.abs(x))
	return math.tanh(x)
end

function stereoFx.Channel:tick(x)
	local s = gain * x

	local diff = (s - self.state)

	local diff2 = dist(diff * 40) * slew

	if math.abs(diff2) > math.abs(diff) then
		diff2 = diff
	end

	local out = self.state + diff2

	local noise = noise_level * (s - out) * (math.random() - 0.5)

	self.state = out
	return out + noise
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		local u1, u2 = self.upsampler.tick(s)

		u1 = self:tick(u1)
		u2 = self:tick(u2)

		local out = self.downsampler.tick(u1, u2)

		-- out = self:tick(s)

		samples[i] = (1 - mix) * s + mix * out
	end
end

params = plugin.manageParams({
	{
		name = "dry/wet",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			mix = val
		end,
	},
	{
		name = "slew time",
		min = 0,
		max = 1,
		default = 0.3,
		changed = function(val)
			slew = math.exp((val - 1) * 10)
		end,
	},
	{
		name = "gain (dB)",
		min = -6,
		max = 12,
		default = 0,
		changed = function(val)
			gain = math.exp(db_to_exp * val)
		end,
	},
	{
		name = "noise level",
		min = -48,
		max = 0,
		default = -6,
		changed = function(val)
			noise_level = math.exp(db_to_exp * val)
		end,
	},
})

--params.resetToDefaults()
