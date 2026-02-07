-- trying to model some optical-style variable attack/release

require("include/protoplug")
local Filter = require("include/dsp/cookbook filters")

local threshold = -12
local ratio = 4
local make_up = 0
local knee = 3

local attack_mix = 0.2

local expFactor = -1000.0 / 44100

local balance = 0.0

local DB_FACTOR = math.log(10) / 20

-- ms to tau
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local attack_slow = timeConstant(20)
local attack_fast = timeConstant(20)
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
		s_w = self.shelf.process(s_w)

		-- log transform
		local peak = math.log(math.abs(s_w) + 0.0001) / DB_FACTOR

		-- gain computer
		peak = peak - threshold
		-- peak = math.max(0, peak)
		if peak < -knee then
			peak = 0
		elseif peak < knee then
			peak = (peak + knee) ^ 2 / (4 * knee)
		end
		peak = (1 - ratio) * peak / ratio

		if peak < self.gain_a then
			-- attack

			local diff = self.gain_a - peak
			diff = diff - math.tanh(diff / 6) * 6
			self.gain_a = self.gain_a - diff * attack_fast

			-- self.gain_c = self.gain_c - (self.gain_c - self.gain_b) * attack_slow
			-- self.gain_c = self.gain_c - (self.gain_c - peak) * attack_slow

			-- self.gain_a = attack_mix * self.gain_b + (1 - attack_mix) * self.gain_c
		else
			-- release
			local diff = self.gain_a - peak
			diff = math.tanh(diff / 2) * 2
			self.gain_a = self.gain_a - diff * release

			self.gain_b = self.gain_a
			self.gain_c = self.gain_a
		end

		local g = self.gain_a
		-- back to linear
		g = math.exp((g + make_up) * DB_FACTOR)

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
			attack_slow = timeConstant(val * 8)
			attack_fast = timeConstant(val * 1)
		end,
	},
	{
		name = "Release",
		min = 1,
		max = 100,
		default = 40,
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

--params.resetToDefaults()
