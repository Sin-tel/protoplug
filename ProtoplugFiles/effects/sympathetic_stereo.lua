--[[
symathetic strings of a piano soundboard
can be used as a sort of reverb

]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/delay_line")

local kap = 0.625

local max_num = 70
local num_active = max_num - 1
local len = 20
local feedback = 0
local coupling = 0

local t = 0

ap = {}
len = {}
filter = {}
filter_high = {}
function calculateStrings()
	for i = 1, max_num do
		local ri = math.random() * 70
		local f = 32.70320 * (2 ^ (ri / 12))

		local ll = (44100 / f)

		print(i, ll)

		ap[i] = Line(math.floor(ll + 10))

		filter[i] = 0
		filter_high[i] = 0

		len[i] = ll
	end
end

calculateStrings()

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local input_l = samples[0][i]
		local input_r = samples[1][i]

		local s = input_l + input_r

		local sum_l = 0
		local sum_r = 0
		local sum = 0

		t = t + 4 / 44100

		for i = 1, num_active do
			local d = ap[i].goBack(len[i] - math.sin(t + i))

			local zh = filter_high[i]

			zh = zh + (d - zh) * kap_high

			filter_high[i] = zh

			-- one pole lowpass
			local v = filter[i] + ((zh - d) - filter[i]) * kap

			filter[i] = v

			if i % 2 == 0 then
				sum_l = sum_l + d
			else
				sum_r = sum_r + d
			end
		end

		sum_l = 2.0 * sum_l / num_active
		sum_r = 2.0 * sum_r / num_active

		local f1 = feedback

		for i = 1, num_active do
			local v = filter[i]
			ap[i].push(s + v * f1)
		end

		local signal = tot

		samples[0][i] = input_l * (1.0 - balance) + sum_l * balance
		samples[1][i] = input_r * (1.0 - balance) + sum_r * balance
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
		name = "number",
		min = 0,
		max = max_num,
		type = "int",
		changed = function(val)
			num_active = val
		end,
	},
	{
		name = "lowpass",
		min = 0,
		max = 1,
		changed = function(val)
			kap = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	{
		name = "highpass",
		min = 0,
		max = 1,
		changed = function(val)
			kap_high = val * val * val * 0.02
		end,
	},
	{
		name = "decay",
		min = 0,
		max = 1,
		changed = function(val)
			feedback = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	{
		name = "seed",
		min = 0,
		max = 100,
		type = "int",
		changed = function(val)
			math.randomseed(val)
			calculateStrings()
		end,
	},
})
