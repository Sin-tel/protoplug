-- Trying to get high initial density without any allpass filters

require("include/protoplug")
local Line = require("include/dsp/delay_line")

local n = 8
local balance = 1

local mix = 0.5
local mix2 = 0.5
local mix3 = 0.5

local size = 1

local k_filter = 0.625

local delays1 = {}
local delays2 = {}
local delays3 = {}
local delays4 = {}
local delays5 = {}
local len1 = {}
local len2 = {}
local len3 = {}
local len4 = {}
local len5 = {}

local filters1 = {}
local filters2 = {}
local filters3 = {}
local filters4 = {}
local filters5 = {}

local max_l = 8000

local g = 1 / math.sqrt(8)

local function copy8(x)
	return { x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8] }
end

local function hadamard8(x)
	local s = { 0, 0, 0, 0, 0, 0, 0, 0 }

	s[1] = g * (x[1] + x[2] + x[3] + x[4] + x[5] + x[6] + x[7] + x[8])
	s[2] = g * (x[1] - x[2] + x[3] - x[4] + x[5] - x[6] + x[7] - x[8])
	s[3] = g * (x[1] + x[2] - x[3] - x[4] + x[5] + x[6] - x[7] - x[8])
	s[4] = g * (x[1] - x[2] - x[3] + x[4] + x[5] - x[6] - x[7] + x[8])
	s[5] = g * (x[1] + x[2] + x[3] + x[4] - x[5] - x[6] - x[7] - x[8])
	s[6] = g * (x[1] - x[2] + x[3] - x[4] - x[5] + x[6] - x[7] + x[8])
	s[7] = g * (x[1] + x[2] - x[3] - x[4] - x[5] - x[6] + x[7] + x[8])
	s[8] = g * (x[1] - x[2] - x[3] + x[4] - x[5] + x[6] + x[7] - x[8])

	return s
end

for i = 1, n do
	delays1[i] = Line(max_l)
	delays2[i] = Line(max_l)
	delays3[i] = Line(max_l)
	delays4[i] = Line(max_l)
	delays5[i] = Line(max_l * 2)

	len1[i] = max_l / 2
	len2[i] = max_l / 2
	len3[i] = max_l / 2
	len4[i] = max_l / 2
	len5[i] = max_l / 2

	filters1[i] = 0
	filters2[i] = 0
	filters3[i] = 0
	filters4[i] = 0
	filters5[i] = 0
end

local function randomize(seed)
	local ll = max_l / n
	math.randomseed(seed)
	for i = 1, n do
		len1[i] = math.random() * ll + ((i - 1) * ll)
		len2[i] = math.random() * ll + ((i - 1) * ll)
		len3[i] = math.random() * ll + ((i - 1) * ll)
		len4[i] = math.random() * ll + ((i - 1) * ll)
		len5[i] = 1.5 * (math.random() * ll + ((i - 1) * ll))
	end
end

local function process_stage(d, delays, len, filter, stage_mix, length_mul)
	local wet_g = math.sqrt(stage_mix)
	local dry_g = math.sqrt(1 - stage_mix)

	local s = copy8(d)
	for i = 1, n do
		delays[i].push(d[i])

		local u = delays[i].goBack_int(len[i] * size * length_mul)

		local v = filter[i] + (u - filter[i]) * k_filter
		filter[i] = v

		d[i] = v
	end

	d = hadamard8(d)

	for i = 1, n do
		d[i] = (d[i] * wet_g) + (s[i] * dry_g)
	end

	return d
end

function plugin.processBlock(samples, smax)
	for k = 0, smax do
		local input_l = samples[0][k]
		local input_r = samples[1][k]

		local d = {
			input_l,
			input_l,
			input_r,
			input_r,
			-input_l,
			-input_l,
			-input_r,
			-input_r,
		}

		d = process_stage(d, delays1, len1, filters1, 1.0, 0.128)
		d = process_stage(d, delays2, len2, filters2, mix, 0.25)
		d = process_stage(d, delays3, len3, filters3, mix2, 0.5)
		d = process_stage(d, delays4, len4, filters4, mix3, 1.0)

		local f = { 0, 0, 0, 0, 0, 0, 0, 0 }
		for i = 1, n do
			local u = delays5[i].goBack_int(len5[i] * size)

			local v = filters5[i] + (u - filters5[i]) * k_filter
			filters5[i] = v

			f[i] = v
		end

		f = hadamard8(f)

		for i = 1, n do
			delays5[i].push(d[i] + mix * f[i])
		end

		local sl = (1 - mix2) * d[1] + mix2 * f[5]
		local sr = (1 - mix2) * d[2] + mix2 * f[6]

		samples[0][k] = input_l * (1.0 - balance) + sl * balance
		samples[1][k] = input_r * (1.0 - balance) + sr * balance
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
		name = "size",
		min = 0.25,
		max = 1,
		changed = function(val)
			size = val
		end,
	},

	{
		name = "decay",
		min = 0.3,
		max = 0.8,
		changed = function(val)
			mix = val
			mix2 = val * val
			mix3 = val * val * val
		end,
	},

	{
		name = "damp",
		min = 0,
		max = 1,
		changed = function(val)
			k_filter = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},

	{
		name = "random seed",
		min = 0,
		max = 100,
		type = "int",
		changed = function(val)
			randomize(val)
		end,
	},
})
