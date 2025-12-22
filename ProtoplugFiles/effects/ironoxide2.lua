-- stripped down to the essentials

--[[
MIT License

Copyright (c) 2018 Chris Johnson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

require("include/protoplug")

local HALF_PI = 0.5 * math.pi

local gain_in = 0
local gain_out = 0

local mix = 1
local ips = 1.0
local lps = 1.0
local noise_level = 0.5

local lowpass_L = 0
local lowpass_R = 0

local highpass_L = 0
local highpass_R = 0

local function sine_dist(x)
	local x_clamped = math.max(math.min(x, HALF_PI), -HALF_PI)
	return math.sin(x_clamped)
end

function plugin.processBlock(samples, smax)
	local lowpass_coef = 1.0 / (1.0 + ips / 15.0)
	local highpass_coef = lps / 430.0

	for k = 0, smax do
		local sample_L = samples[0][k]
		local sample_R = samples[1][k]

		local dry_L = sample_L
		local dry_R = sample_R

		-- highpass
		highpass_L = (highpass_L * (1 - highpass_coef)) + (sample_L * highpass_coef)
		highpass_R = (highpass_R * (1 - highpass_coef)) + (sample_R * highpass_coef)
		sample_L = sample_L - highpass_L
		sample_R = sample_R - highpass_R

		local pre_noise_L = sample_L
		local pre_noise_R = sample_R

		-- input distortion
		sample_L = sine_dist(sample_L * gain_in)
		sample_R = sine_dist(sample_R * gain_in)

		-- 1 pole lowpass
		lowpass_L = lowpass_L * lowpass_coef + sample_L * (1 - lowpass_coef)
		lowpass_R = lowpass_R * lowpass_coef + sample_R * (1 - lowpass_coef)
		sample_L = lowpass_L
		sample_R = lowpass_R

		-- second distortion stage
		sample_L = sine_dist(sample_L) * gain_out
		sample_R = sine_dist(sample_R) * gain_out

		-- input-dependent noise
		local noise_a = math.random() * noise_level

		sample_L = sample_L * (1.0 - noise_a) + (pre_noise_L * noise_a)
		sample_R = sample_R * (1.0 - noise_a) + (pre_noise_R * noise_a)

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
		name = "gain",
		min = -18,
		max = 18,
		default = 0,
		changed = function(val)
			gain_in = math.pow(10, val / 20)
			gain_out = 1 / gain_in
		end,
	},

	{
		name = "ips",
		min = 0,
		max = 1,
		default = 0.8,
		changed = function(val)
			ips = (((val * val) * (val * val) * 148.5) + 1.5) * 1.1
		end,
	},

	{
		name = "lps",
		min = 0,
		max = 1,
		default = 0.2,
		changed = function(val)
			lps = (((val * val) * (val * val) * 148.5) + 1.5) * 1.1
		end,
	},

	{
		name = "noise",
		min = 0,
		max = 1,
		default = 0.5,
		changed = function(val)
			noise_level = val * val * 0.3
		end,
	},
})

--params.resetToDefaults()
