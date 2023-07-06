-- simple stereo widener that is "mono compatible"
-- the wet signal is added inverted to left and right channels so it cancels when you sum it

require("include/protoplug")
local Line = require("include/dsp/delay_line")

delay_l = Line(500)
delay_r = Line(500)

local amount = val

local apk = -0.9

-- max delay in samples
-- this is for 44.1kHz, should really make it independent of sample rate
local delay = 140

local prev_l = 0.0
local prev_r = 0.0

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local in_l = samples[0][i]
		local in_r = samples[1][i]

		delay_l.push(in_l)
		delay_r.push(in_r)

		-- delay
		local d_l = delay_l.goBack(delay * amount)
		local d_r = delay_r.goBack(delay * amount)

		-- allpass
		local v_l = d_l - apk * prev_l
		local v_r = d_r - apk * prev_r

		local out_l = prev_l + apk * v_l
		local out_r = prev_r + apk * v_r

		prev_l = v_l
		prev_r = v_r

		samples[0][i] = in_l + amount * out_l
		samples[1][i] = in_r - amount * out_r
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
})
