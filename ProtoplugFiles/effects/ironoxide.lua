require("include/protoplug")

local HALF_PI = 0.5 * math.pi
local TWO_PI = 2 * math.pi

local mix = 1
local B = 0.562341325190349
local C = 0.562341325190349
local D = 0.5
local E = 0.5

local fl_counter = 0
local fl_index = 0
local next_rate = 0.5
local flutter_rate = 0.5

local buf_L = ffi.new("double[100]")
local buf_R = ffi.new("double[100]")

local high_L = 0
local high_R = 0

local low_L = 0
local low_R = 0

local prev_dry_L = 0
local prev_dry_R = 0

local sweep = 0

local function sine_dist(x)
	local x_clamped = math.max(math.min(x, HALF_PI), -HALF_PI)
	return math.sin(x_clamped)
end

function plugin.processBlock(samples, smax)
	local ips = (((B * B) * (B * B) * 148.5) + 1.5) * 1.1
	local lps = (((C * C) * (C * C) * 148.5) + 1.5) * 1.1

	local depth = D * D
	local flutter_trim = 0.00581
	local sweep_trim = (0.0005 * depth)
	local fl_rate_change = 0.006

	local noise_level = E * 0.5

	local high_coef = 1.0 / (1.0 + ips / 15.0)
	local low_coef = lps / 430.0

	local out_scale = ips / 5.0

	local noise_offset = 0.04 + (0.11 / math.sqrt(ips))

	for k = 0, smax do
		local sample_L = samples[0][k]
		local sample_R = samples[1][k]

		local dry_L = sample_L
		local dry_R = sample_R

		-- flutter read pointer update
		fl_counter = fl_counter - 1
		if fl_counter < 0 or fl_counter > 30 then
			fl_counter = 30
		end
		fl_index = fl_counter
		buf_L[fl_index + 31] = sample_L
		buf_L[fl_index] = sample_L
		buf_R[fl_index + 31] = sample_R
		buf_R[fl_index] = sample_R

		-- flutter index
		local offset = (1.0 + math.sin(sweep)) * depth
		local interpolate = offset - math.floor(offset)
		fl_index = fl_index + math.floor(offset)

		-- read back buffer with linear interpolation
		local fl_L = (buf_L[fl_index] * (1 - interpolate))
		local fl_R = (buf_R[fl_index] * (1 - interpolate))
		fl_L = fl_L + (buf_L[fl_index + 1] * interpolate)
		fl_R = fl_R + (buf_R[fl_index + 1] * interpolate)

		-- update flutter LFO speed and index
		flutter_rate = next_rate * fl_rate_change + flutter_rate * (1 - fl_rate_change)
		sweep = sweep + flutter_rate * flutter_trim
		sweep = sweep + sweep * sweep_trim
		if sweep >= TWO_PI then
			sweep = 0.0
			next_rate = 0.02 + (math.random() * 0.98)
		end

		sample_L = fl_L
		sample_R = fl_R

		-- lowpass
		low_L = (low_L * (1 - low_coef)) + (sample_L * low_coef)
		low_R = (low_R * (1 - low_coef)) + (sample_R * low_coef)
		sample_L = sample_L - low_L
		sample_R = sample_R - low_R

		-- input distortion
		sample_L = sine_dist(sample_L)
		sample_R = sine_dist(sample_R)

		-- "shaping network" aka 1 pole high shelf
		high_L = high_L * high_coef + sample_L
		high_R = high_R * high_coef + sample_R

		sample_L = high_L * high_coef * out_scale
		sample_R = high_R * high_coef * out_scale

		-- second distortion stage
		sample_L = sine_dist(sample_L)
		sample_R = sine_dist(sample_R)

		-- input-dependent noise
		local noise_a = (0.55 + noise_offset + (math.random() * noise_offset)) * noise_level

		sample_L = sample_L * (1.0 - noise_a) + (prev_dry_L * noise_a)
		sample_R = sample_R * (1.0 - noise_a) + (prev_dry_R * noise_a)

		prev_dry_L = dry_L
		prev_dry_R = dry_R

		samples[0][k] = (1 - mix) * dry_L + mix * sample_L
		samples[1][k] = (1 - mix) * dry_R + mix * sample_R
	end
end

params = plugin.manageParams({
	{
		name = "dry/wet",
		min = 0,
		max = 1,
		default = 1,
		changed = function(val)
			mix = val
		end,
	},

	{
		name = "ips",
		min = 0,
		max = 1,
		default = 0.562341325190349,
		changed = function(val)
			B = val
		end,
	},

	{
		name = "lps",
		min = 0,
		max = 1,
		default = 0.562341325190349,
		changed = function(val)
			C = val
		end,
	},
	{
		name = "flutter",
		min = 0,
		max = 1,
		default = 0.5,
		changed = function(val)
			D = val
		end,
	},

	{
		name = "noise",
		min = 0,
		max = 1,
		default = 0.5,
		changed = function(val)
			E = val
		end,
	},
})

-- params.resetToDefaults()
