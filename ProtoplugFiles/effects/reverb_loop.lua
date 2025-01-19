require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
-- local Line = require("include/dsp/delay_line")
local Filter = require("include/dsp/cookbook filters")

local balance = 0.5
local size = 1
local size_ = 1
local feedback = 0
local t_60 = 1.0
local time = 0

local l1 = 4217
local l2 = 3163
local l3 = 4453
local l4 = 3720

local delay1 = Line(5000)
local delay2 = Line(5000)
local delay3 = Line(5000)
local delay4 = Line(5000)

local k_ap_in = 0.625
local k_ap = 0.625

local ap1 = Line(500)
local ap2 = Line(500)
local ap3 = Line(500)
local ap4 = Line(500)
local ap5 = Line(1000)
local ap6 = Line(3000)
local ap7 = Line(1000)
local ap8 = Line(3000)

local ap1_l = 142
local ap2_l = 107
local ap3_l = 379
local ap4_l = 277

local ap5_l = 905
local ap6_l = 1956
local ap7_l = 672
local ap8_l = 1800

local function allpass(s, ap, l, k)
	local d = ap.goBack_int(l)
	local v = s - k * d
	ap.push(v)
	return k * v + d
end

local shelf1 = Filter({
	type = "hs",
	f = 6000,
	gain = -3,
	Q = 0.5,
})

local shelf2 = Filter({
	type = "hs",
	f = 6000,
	gain = -3,
	Q = 0.5,
})

-- local function softclip(x)
-- 	if x <= -1 then
-- 		return -2.0 / 3.0
-- 	elseif x >= 1 then
-- 		return 2.0 / 3.0
-- 	else
-- 		return x - (x * x * x) / 3.0
-- 	end
-- end

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local input_l = samples[0][i]
		local input_r = samples[1][i]

		size_ = size_ - (size_ - size) * 0.001

		local s = 0.5 * (input_l + input_r)

		time = time + 1 / 44100

		-- local mod = math.sin(time * 2.5) * 64.0
		local mod = 1.0 + 0.005 * math.sin(5.35 * time)
		local mod2 = 1.0 + 0.008 * math.sin(3.12 * time)

		s = allpass(s, ap1, ap1_l, k_ap_in)
		s = allpass(s, ap2, ap2_l, k_ap_in)
		s = allpass(s, ap3, ap3_l, k_ap_in)
		s = allpass(s, ap4, ap4_l, k_ap_in)

		local u1 = delay1.goBack(l1 * size_ * mod)
		local u2 = delay2.goBack(l2 * size_)
		local u3 = delay3.goBack(l3 * size_ * mod2)
		local u4 = delay4.goBack(l4 * size_)

		u4 = u4 + s
		u4 = shelf1.process(u4)
		-- sign
		u4 = -allpass(u4, ap5, ap5_l, k_ap)
		delay1.push(u4)

		-- damping
		u1 = u1
		u1 = allpass(u1, ap6, ap6_l, k_ap)
		delay2.push(u1 * feedback)

		u2 = u2 + s
		u2 = shelf2.process(u2)
		u2 = allpass(u2, ap7, ap7_l, k_ap)
		-- u2 = softclip(u2)
		delay3.push(u2)

		u3 = allpass(u3, ap8, ap8_l, k_ap)
		delay4.push(u3 * feedback)

		local sl = u1 + 0.2 * u2
		local sr = u3 + 0.2 * u4

		samples[0][i] = input_l * (1.0 - balance) + sl * balance
		samples[1][i] = input_r * (1.0 - balance) + sr * balance
	end
end

local function setFeedback(t)
	if t then
		t_60 = t
	end
	if t_60 > 15 then
		feedback = 1.0
	else
		feedback = 10 ^ (-(60 * 8000 * size) / (t_60 * 44100 * 20))
	end
end

params = plugin.manageParams({
	{
		name = "Dry/Wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "Size",
		min = 0.01,
		max = 1.00,
		changed = function(val)
			size = val
			setFeedback()
		end,
	},
	{
		name = "Decay Time",
		min = 0.0,
		max = 1.0,
		changed = function(val)
			setFeedback(2 ^ (8 * val - 4))
		end,
	},
	{
		name = "Diffusion",
		min = 0.0,
		max = 0.625,
		changed = function(val)
			k_ap_in = val
		end,
	},
})
