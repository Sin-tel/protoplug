--Analog-style limiter

require("include/protoplug")

-- ms to tau
local T_LN = 4605.1704
local function time_constant(t)
	local denom = 44100 * t
	return 1.0 - math.exp(-T_LN / denom)
end

local release = time_constant(80)
local attack = time_constant(5)

print(attack)

local gain_in = 1.

stereoFx.init()
function stereoFx.Channel:init()
	self.gain_p = 1
end

local function clip(x)
	local s = math.min(math.max(x, -5 / 4), 5 / 4)
	return s - (256. / 3125.) * s ^ 5
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local x = gain_in * samples[i]
		local peak = math.abs(x)
		local gain = math.min(1.0, 1.0 / peak)

		if gain < self.gain_p then
			self.gain_p = self.gain_p - (self.gain_p - gain) * attack
		else
			self.gain_p = self.gain_p - (self.gain_p - gain) * release
		end

		local g = self.gain_p

		x = x * g

		x = clip(x * 1.1)

		samples[i] = x
	end
end

params = plugin.manageParams({
	{
		name = "gain",
		min = -24,
		max = 24,
		default = 0,
		changed = function(val)
			gain_in = 10 ^ (val / 20)
		end,
	},
	{
		name = "Release",
		min = 1,
		max = 800,
		default = 200,
		changed = function(val)
			release = time_constant(val * 2)
		end,
	},
})

-- params.resetToDefaults()
