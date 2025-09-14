-- simple stereo widener that is "mono compatible"
-- the wet signal is added inverted to left and right channels so it cancels when you sum it

require("include/protoplug")
local Line = require("include/dsp/delay_line")
local Filter = require("include/dsp/cookbook_svf")

local delay = Line(500)

local amount = 0

-- local apk = -0.92

-- max delay in samples
-- this is for 44.1kHz, should really make it independent of sample rate
local max_delay = 140

local ap1 = Filter({ type = "ap", f = 50, Q = 0.5 })
local ap2 = Filter({ type = "ap", f = 300, Q = 0.5 })
local hp = Filter({ type = "hp", f = 30, Q = 0.7 })

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local in_l = samples[0][i]
		local in_r = samples[1][i]

		local s_in = 0.5 * (in_l + in_r)
		delay.push(s_in)

		local d_l = delay.goBack(max_delay * amount)

		local y = ap1.process(d_l)
		y = ap2.process(y)
		y = hp.process(y)

		samples[0][i] = in_l + amount * y
		samples[1][i] = in_r - amount * y
	end
end

params = plugin.manageParams({
	{
		name = "amount",
		min = 0,
		max = 1,
		changed = function(val)
			amount = val
		end,
	},

	-- {
	-- 	name = "low cut",
	-- 	min = 0,
	-- 	max = 6,
	-- 	changed = function(val)
	-- 		highpass_f = math.exp(-val)
	-- 		print(highpass_f)
	-- 	end,
	-- },
	-- {
	-- 	name = "allpass",
	-- 	min = -0.99,
	-- 	max = 0.99,
	-- 	changed = function(val)
	-- 		apk = val
	-- 	end,
	-- },
})
