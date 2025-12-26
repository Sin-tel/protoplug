--[[

2:1 compander, following NE570 datasheet. In practice attack/release is probably not 100% the same.

The paired feedback / feedforward path make it transparent when the intermediate processing is linear:

--[/]-----+----+-----[*]-->
   ^      |    |      ^
   |      v    v      |
   +-[LP]-+    +-[LP]-+


With a reasonable amount of smoothing, 1 sample delay in feedback loop is negligible.

]]

require("include/protoplug")

local Filter = require("include/dsp/cookbook_svf")

-- global dsp
local sample_rate = 44100
plugin.addHandler("prepareToPlay", function()
	sample_rate = plugin.getSampleRate()
end)

-- parameters
local balance = 0.5

-- ms (time to 10^-2) to tau
local T_LN = 4605.1704
local function time_constant(t)
	local denom = sample_rate * t
	return 1.0 - math.exp(-T_LN / denom)
end

-- 2.2uF * 10kOhm = 22ms
-- 1/e ~ 22ms -> 1/100 ~ 100ms
-- can go a lot lower in usual applications
local env_s = time_constant(100.0)

-- distortion
local even = 0.05
local odd = 0.02

local function dist(x)
	if x > 1 then
		return 1 - odd - even
	elseif x < -1 then
		return -1 + odd - even
	else
		return x - even * x * x - odd * x * x * x
	end
end

stereoFx.init()
function stereoFx.Channel:init(left)
	-- envelopes
	self.env_in = 0
	self.env_out = 0

	self.high = Filter({ type = "hp", f = 10, gain = 0, Q = 0.5 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local in_s = samples[i]

		local s = in_s

		-- 2:1 compression (feedback)
		s = s / (self.env_in + 1e-7)
		local env_in = math.abs(s)
		self.env_in = self.env_in - (self.env_in - env_in) * env_s

		-- 2:1 feedback compression (zero delay feedback)
		-- local b = self.env_in * (1.0 - env_s)
		-- local c = math.abs(s) * env_s
		-- self.env_in = 0.5 * (b + math.sqrt(b * b + 4.0 * c))
		-- s = s / (self.env_in + 1e-7)

		-- non-ideal transfer
		s = s + 0.003 * (math.random() - 0.5)
		s = dist(s)
		-- s = s + 0.02 * math.abs(s)
		s = self.high.process(s)

		local out = s

		-- output 1:2 expansion (feedforward)
		local env_out = math.abs(out)
		self.env_out = self.env_out - (self.env_out - env_out) * env_s
		out = out * self.env_out

		samples[i] = in_s * (1 - balance) + out * balance
	end
end

params = plugin.manageParams({

	{
		name = "dry/wet",
		min = 0.0,
		max = 1.0,
		default = 1.0,
		changed = function(val)
			balance = val
		end,
	},
})

params.resetToDefaults()
