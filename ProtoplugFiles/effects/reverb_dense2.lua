-- can replace first FDN with single delay line

require("include/protoplug")
local Line = require("include/dsp/delay_line")

local n = 16
local balance = 1

local size = 1
local size_ = 1

local k_filter = 0.7

local fb_gains = {}
for i = 1, n do
	fb_gains[i] = 0.5
end

local mix = 1.0

local delays1 = {}
local delays2 = {}
local delays3 = {}

local len1 = {}
local len2 = {}
local len3 = {}

local filters1 = {}
local filters2 = {}
local filters3 = {}

local max_l = 8000

local function copy(x)
	local y = {}
	for i = 1, n do
		y[i] = x[i]
	end
	return y
end

local g = 1 / math.sqrt(n)

local function hadamard(x)
	local s = {}
	for i = 1, n do
		s[i] = x[i]
	end

	local h = 1
	while h < n do
		for i = 1, n, h * 2 do
			for j = i, i + h - 1 do
				local a, b = s[j], s[j + h]
				s[j] = a + b
				s[j + h] = a - b
			end
		end
		h = h * 2
	end

	for i = 1, n do
		s[i] = s[i] * g
	end
	return s
end

for i = 1, n do
	delays1[i] = Line(max_l)
	delays2[i] = Line(max_l)
	delays3[i] = Line(max_l)

	len1[i] = max_l / 2
	len2[i] = max_l / 2
	len3[i] = max_l / 2

	filters1[i] = 0
	filters2[i] = 0
	filters3[i] = 0
end

local function randomize(seed)
	local ll = max_l / n
	math.randomseed(seed)
	for i = 1, n do
		len1[i] = math.random() * ll + ((i - 1) * ll)
		len2[i] = math.random() * ll + ((i - 1) * ll)
		--len3[i] = math.random() * ll + ((i - 1) * ll)
		len3[i] = (math.random() * 0.5 + 0.4) * max_l
	end
end

local function process_stage(d, delays, len, filter, stage_mix, length_mul)
	local wet_g = math.sqrt(stage_mix)
	local dry_g = math.sqrt(1 - stage_mix)

	local s = copy(d)
	for i = 1, n do
		delays[i].push(d[i])

		local u = delays[i].goBack_int(len[i] * size * length_mul)

		local v = filter[i] + (u - filter[i]) * k_filter
		filter[i] = v
		d[i] = v
	end

	d = hadamard(d)

	for i = 1, n do
		d[i] = (d[i] * wet_g) + (s[i] * dry_g)
	end

	return d
end

local a = {}
for i = 1, n do
	a[i] = 2.7 * math.exp(-0.14 * i)
end

function plugin.processBlock(samples, smax)
	for k = 0, smax do
		size = size + (size_ - size) * 0.001

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

			input_l,
			input_l,
			input_r,
			input_r,
			-input_l,
			-input_l,
			-input_r,
			-input_r,
		}

		assert(#d == n)

		for i = 1, n do
			d[i] = d[i] * a[i]
		end

		d = process_stage(d, delays1, len1, filters1, 1.0, 1.0)
		d = process_stage(d, delays2, len2, filters2, 1.0, 1.0 * 0.45)

		local f = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
		assert(#f == n)

		for i = 1, n do
			local u = delays3[i].goBack_int(len3[i] * size)
			local v = filters3[i] + (u - filters3[i]) * k_filter
			filters3[i] = v
			f[i] = v * fb_gains[i]
			---f[i] = u * fb_gains[i]
		end

		f = hadamard(f)

		for i = 1, n do
			delays3[i].push(d[i] + f[i])
		end

		local sl = (1 - mix) * d[7] + mix * f[1]
		local sr = (1 - mix) * d[8] + mix * f[2]

		-- local sl = d[7]
		-- local sr = d[8]

		samples[0][k] = 0.5 * input_l * (1.0 - balance) + sl * balance
		samples[1][k] = 0.5 * input_r * (1.0 - balance) + sr * balance
	end
end

local function from_db(x)
	return 10 ^ (x / 20)
end

local function set_fb(t60)
	for i = 1, n do
		local l = len3[i]
		fb_gains[i] = from_db((-60 * l) / (t60 * 44100))
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
			size_ = val
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
		name = "decay time",
		min = 0.1,
		max = 10.0,
		changed = function(val)
			set_fb(val)
			mix = 0.3 + 0.3 * from_db((-60 * max_l * 2) / (val * 44100))
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
