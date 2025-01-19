require("include/protoplug")
local Filter = require("include/dsp/cookbook filters")

local threshold = -12
local ratio = 4
local make_up = 0
local knee = 3

local attack_mix = 0.15

local expFactor = -1000.0 / 44100

local balance = 0.0

local DB_FACTOR = math.log(10) / 20

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local attack = timeConstant(20)
local attack2 = timeConstant(20)
local release = timeConstant(80)

stereoFx.init()
function stereoFx.Channel:init(is_left)
	self.gain_a = 0
	self.gain_b = 0
	self.gain_c = 0
	self.is_left = is_left

	self.highpass = Filter({ type = "hp", f = 100, Q = 0.5 })
	self.shelf = Filter({ type = "hs", f = 1500, gain = 4, Q = 0.5 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s_in = samples[i]

		-- sidechain loudness weighting
		local s_w = self.highpass.process(s_in)
		local s_w = self.shelf.process(s_w)

		-- log transform
		local peak_in = math.log(math.abs(s_w) + 0.0001) / DB_FACTOR

		-- gain computer
		local gain = peak_in - threshold
		-- gain = math.max(0, gain)
		if gain < -knee then
			gain = 0
		elseif gain < knee then
			gain = (gain + knee) ^ 2 / (4 * knee)
		end
		gain = (1 - ratio) * gain / ratio

		-- peak release
		if gain < self.gain_a then
			self.gain_a = gain
		else
			self.gain_a = self.gain_a - (self.gain_a - gain) * release
		end

		-- attack smoothing
		self.gain_b = self.gain_b - (self.gain_b - self.gain_a) * attack
		self.gain_c = self.gain_c - (self.gain_c - self.gain_a) * attack2

		local g = attack_mix * self.gain_b + (1 - attack_mix) * self.gain_c

		-- back to linear
		local g = math.exp((g + make_up) * DB_FACTOR)

		g = g * balance + (1 - balance)

		-- if self.is_left then
		-- 	samples[i] = g * s_in
		-- else
		-- 	samples[i] = g
		-- end
		samples[i] = g * s_in
	end
end

params = plugin.manageParams({
	{
		name = "Dry Wet",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "Threshold",
		min = -48,
		max = 0,
		default = -24,
		changed = function(val)
			threshold = val
		end,
	},
	{
		name = "Ratio",
		min = 1,
		max = 10,
		default = 4,
		changed = function(val)
			ratio = val
		end,
	},
	{
		name = "Attack",
		min = 0.1,
		max = 50,
		default = 15,
		changed = function(val)
			attack = timeConstant(val * 16)
			attack2 = timeConstant(val * 0.5)
		end,
	},
	{
		name = "Release",
		min = 1,
		max = 400,
		default = 120,
		changed = function(val)
			release = timeConstant(val)
		end,
	},
	{
		name = "MakeUp",
		min = 0,
		max = 36,
		default = 0,
		changed = function(val)
			make_up = val
		end,
	},
	-- {
	-- 	name = "Mix",
	-- 	min = 0,
	-- 	max = 1,
	-- 	default = 0.15,
	-- 	changed = function(val)
	-- 		attack_mix = val
	-- 	end,
	-- },
})

params.resetToDefaults()
