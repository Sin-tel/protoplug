require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local high = cbFilter({ type = "hp", f = 5, gain = 0, Q = 0.7 })

local size = 60

local sparse = 150 / (size * size)

print(sparse)

local w_type = ffi.typeof("double[$][$]", size + 1, size + 1)
local w = ffi.new(w_type)
local w_in = ffi.new("double[?]", size + 1)
local w_out = ffi.new("double[?]", size + 1)
local w_bias = ffi.new("double[?]", size + 1)
local f_arr = ffi.new("double[?]", size + 1)

local function rnorm()
	return math.log(1 / math.random()) ^ 0.5 * math.cos(math.pi * math.random())
end

for i = 1, size do
	w_in[i] = i % 2
	w_out[i] = (i + 1) % 2

	f_arr[i] = 1.0

	for j = 1, size do
		if math.random() < sparse then
			w[i][j] = math.random() - 0.5
		end
	end
end

local function softclip(x)
	local s = math.max(-3.0, math.min(3.0, x))
	return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)
end

local arr = ffi.new("double[?]", size + 1)
local a_new = ffi.new("double[?]", size + 1)
local gain = 0
local gain_ = 0
local bias = 0
local bias_ = 0
local freq = 0.5
local freq_ = 0

function plugin.processBlock(samples, smax)
	for k = 0, smax do
		gain = gain - (gain - gain_) * 0.001
		bias = bias - (bias - bias_) * 0.001
		freq = freq - (freq - freq_) * 0.001

		for i = 1, size do
			a_new[i] = bias * w_bias[i]
			for j = 1, size do
				a_new[i] = a_new[i] + w[i][j] * arr[j] * gain
			end
		end

		local out = 0
		for i = 1, size do
			local y = softclip(a_new[i])
			local v = y - arr[i]

			arr[i] = arr[i] + math.min(freq * f_arr[i], 1.0) * v + 0.0001 * (math.random() - 0.5)
			out = out + w_out[i] * y
		end

		out = 2 * out / size
		out = high.process(out)

		samples[0][k] = out
		samples[1][k] = out
	end
end

params = plugin.manageParams({
	{
		name = "Gain",
		min = 0,
		max = 8,
		default = 1,
		changed = function(val)
			gain_ = val
		end,
	},
	{
		name = "bias",
		min = 0,
		max = 3,
		default = 0,
		changed = function(val)
			bias_ = val
		end,
	},
	{
		name = "pitch",
		min = 10,
		max = 100,
		default = 0,
		changed = function(val)
			freq_ = 2 ^ ((val - 20) / 12) * 261.625565 / 44100.0

			--	print(f)
		end,
	},

	{
		name = "seed",
		min = 0,
		max = 500,
		default = 1,
		type = "int",
		changed = function(val)
			math.randomseed(val)
			for i = 1, size do
				w_bias[i] = math.random() - 0.5

				local ff = rnorm()

				ff = math.exp(ff * 3)
				-- print(ff)
				f_arr[i] = ff
				for j = 1, size do
					w[i][j] = 0
					if math.random() < sparse then
						local idx = i + j * size + val
						w[i][j] = math.random() - 0.5
					end
				end
			end
		end,
	},
})

--params.resetToDefaults()
