--[[
n pole phase with zero delay feedback path
]]

require("include/protoplug")

local TWO_PI = 2 * math.pi

local sample_rate = 44100
plugin.addHandler("prepareToPlay", function()
	sample_rate = plugin.getSampleRate()
end)

local k_val = 3.0
local l = 8
local feedback = 0
local balance = 1.0

local lfo_freq = TWO_PI * 0.5 / sample_rate
local lfo_mod = 0.5

stereoFx.init()

local function compute_kap(x)
	-- local z = 0.49 * math.exp(x - 6)
	-- return (1 - math.tan(math.pi * z)) / (1 + math.tan(math.pi * z))

	-- approximation
	return 1.148 + 1 / (x - 6.475)
end

local function softclip(x)
	if x <= -1.5 then
		return -1
	elseif x >= 1.5 then
		return 1
	else
		return x - (4 / 27) * x * x * x
	end
end

function stereoFx.Channel:init(left)
	self.ap = {}
	self.k = {}
	for i = 1, l do
		self.ap[i] = 0
	end
	self.k_val = 0.5

	-- lfo state
	self.lfo_phase_offset = 0
	if left then
		self.lfo_phase_offset = 0.5 * math.pi
	end
	self.lfo_phase = 0.
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		self.k_val = 0.999 * self.k_val + 0.001 * k_val
		-- lfo mod
		self.lfo_phase = self.lfo_phase + lfo_freq
		local lfo = lfo_mod * math.sin(self.lfo_phase + self.lfo_phase_offset)
		local kap = compute_kap(self.k_val + lfo)

		local input = samples[i]

		local x = input

		-- compute feedback loop
		local k = -kap
		local k2 = (1.0 - k * k)

		local G = 1
		local S = 0

		for j = 1, l do
			G = G * k
			S = S * k + self.ap[j] * k2
		end

		-- one iteration of newton-rhapson with guess = 0
		local u = (x - feedback * S) / (1 + feedback * G)

		-- update state
		u = softclip(u)

		for j = 1, l do
			local d = self.ap[j]
			local v = u - k * d
			u = k * v + d
			self.ap[j] = v
		end

		local out = -u

		samples[i] = (input * (1.0 - balance) + out * balance)
	end
end

params = plugin.manageParams({
	{
		name = "Dry/Wet",
		min = 0,
		max = 1.0,
		default = 1.0,
		changed = function(val)
			balance = 0.5 * val
		end,
	},
	{
		name = "freq",
		min = 1,
		max = 4,
		default = 2,
		changed = function(val)
			k_val = val
		end,
	},
	{
		name = "feedback",
		min = 0,
		max = 1.0,
		default = 0.15,
		changed = function(val)
			feedback = val
		end,
	},

	{
		name = "rate",
		min = 0.1,
		max = 4,
		default = 0.7,
		changed = function(val)
			lfo_freq = TWO_PI * val / sample_rate
		end,
	},

	{
		name = "depth",
		min = 0,
		max = 1,
		default = 0.4,
		changed = function(val)
			lfo_mod = val
		end,
	},
})

params.resetToDefaults()
