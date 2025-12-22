require("include/protoplug")
local cbFilter = require("include/dsp/cookbook_svf")

local gain_in = 1
local gain_compensate = 1
local gain_out = 1
local bias = 0.36

local balance = 1

-- ms to tau
local expFactor = -1000.0 / 44100
local function timeConstant(x)
	return 1.0 - math.exp(expFactor / x)
end

local release = timeConstant(80)

local function softclip(x)
	local s = math.min(math.max(x, -3.0), 3.0)
	return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)
end

local function tube(x)
	local w = math.max(x, 0)

	local w2 = w * w
	local s = x + 0.13 * w * w2 + 0.407 * w2 * w2

	return softclip(s)
end

stereoFx.init()
function stereoFx.Channel:init()
	self.prev = 0
	self.peak_input_filter = cbFilter({ type = "hp", f = 50, gain = 0, Q = 0.7 })
	self.peak_filter = cbFilter({ type = "lp", f = 5, gain = 0, Q = 0.7 })

	self.highpass_out = cbFilter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
	self.pre = cbFilter({ type = "tilt", f = 180, gain = 4.5, Q = 0.4 })
	self.post = cbFilter({ type = "tilt", f = 180, gain = -4.5, Q = 0.4 })

	self.peak = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i] * gain_in

		local peak = self.peak_input_filter.process(s)
		peak = math.abs(peak)

		if peak > self.peak then
			self.peak = peak
		else
			self.peak = self.peak - (self.peak - peak) * release
		end

		local w = self.peak_filter.process(self.peak)

		s = self.pre.process(s)

		local out = tube(s + 0.25 - bias * w)

		out = self.highpass_out.process(out) * gain_out * gain_compensate
		out = self.post.process(out)

		samples[i] = (1.0 - balance) * samples[i] + balance * out
		-- samples[i] = w
	end
end

params = plugin.manageParams({
	{
		name = "dry/wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "drive",
		min = -12,
		max = 12,
		changed = function(val)
			gain_in = math.pow(10, val / 20)
			local k = val
			if val > 0 then
				k = k * 0.75
			end
			gain_compensate = math.pow(10, -k / 20)
		end,
	},
	{
		name = "output",
		min = 0,
		max = 12,
		changed = function(val)
			gain_out = math.pow(10, val / 20)
		end,
	},
})
