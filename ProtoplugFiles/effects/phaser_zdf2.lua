-- Same but using second order stages instead

require("include/protoplug")

local Filter = require("include/dsp/cookbook_svf")

local TWO_PI = 2 * math.pi

local sample_rate = 44100
plugin.addHandler("prepareToPlay", function()
	sample_rate = plugin.getSampleRate()
end)

local f_base = 1000.0
local q_factor = 0.5

local n_stages = 4
local feedback = 0
local balance = 1.0

local lfo_freq = TWO_PI * 0.5 / sample_rate
local lfo_mod = 0.5

stereoFx.init()

local function softclip(x)
	if x <= -1.5 then
		return -1
	elseif x >= 1.5 then
		return 1
	else
		return x - (4 / 27) * x * x * x
	end
end

local function softclip2(x)
	local s = math.min(math.max(x, -3.0), 3.0)
	return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)
end

function stereoFx.Channel:init(left)
	self.ap = {}
	for j = 1, n_stages do
		self.ap[j] = Filter({ type = "ap", f = f_base, Q = q_factor })
	end

	-- lfo state
	self.lfo_phase_offset = 0
	if left then
		self.lfo_phase_offset = 0.5 * math.pi
	end
	self.lfo_phase = 0.
end

function stereoFx.Channel:processBlock(samples, smax)
	-- lfo mod
	self.lfo_phase = self.lfo_phase + lfo_freq * smax
	local lfo = 0.9 * lfo_mod * math.sin(self.lfo_phase + self.lfo_phase_offset)
	self:updateFilters(lfo)

	for i = 0, smax do
		local input = samples[i]

		local x = input

		-- predict instantaneous response y = G*x + S
		local G = 1
		local S = 0

		for j = 1, n_stages do
			local g_local, s_local = self.ap[j].predict()
			G = G * g_local
			S = S * g_local + s_local
		end

		-- solve for feedback loop
		x = (x - feedback * S) / (1 + feedback * G)

		-- update state
		x = softclip2(x)
		for j = 1, n_stages do
			x = self.ap[j].process(x)
		end

		local out = -x

		samples[i] = (input * (1.0 - balance) + out * balance)
	end
end

function stereoFx.Channel:updateFilters(lfo)
	for j = 1, n_stages do
		self.ap[j].update({ f = f_base * (1.0 + lfo), Q = q_factor })
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
		min = 0,
		max = 6,
		default = 2.5,
		changed = function(val)
			f_base = 20000 * math.exp(val - 6)
			print(f_base)
		end,
	},
	{

		name = "Q",
		min = 0.1,
		max = 5.0,
		default = 0.5,
		changed = function(val)
			q_factor = val
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
