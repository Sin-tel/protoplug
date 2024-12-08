require("include/protoplug")

stereoFx.init()

local size = 12

local sparse = 150 / (size * size)

local gain_in = 1.0
local gain = 1.0
local bias = 0.0
local f = 1.0

print(sparse)

local w_type = ffi.typeof("double[$][$]", size + 1, size + 1)
local w = ffi.new(w_type)
local w_in = ffi.new("double[?]", size + 1)
local w_out = ffi.new("double[?]", size + 1)
local w_bias = ffi.new("double[?]", size + 1)

for i = 1, size do
	w_in[i] = i % 2
	w_out[i] = (i + 1) % 2
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

function stereoFx.Channel:init()
	self.arr = ffi.new("double[?]", size + 1)
	self.a_new = ffi.new("double[?]", size + 1)
	self.gain = 0
	self.bias = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for k = 0, smax do
		self.gain = self.gain - (self.gain - gain) * 0.001
		self.bias = self.bias - (self.bias - bias) * 0.001

		local s = samples[k]

		for i = 1, size do
			self.a_new[i] = w_in[i] * s * gain_in + self.bias * w_bias[i]
			for j = 1, size do
				self.a_new[i] = self.a_new[i] + w[i][j] * self.arr[j] * self.gain
			end
		end

		local out = 0
		for i = 1, size do
			local y = softclip(self.a_new[i])
			local v = y - self.arr[i]

			self.arr[i] = self.arr[i] + f * v + 0.0001 * (math.random() - 0.5)
			out = out + w_out[i] * y
		end

		samples[k] = 2 * out / size
	end
end

params = plugin.manageParams({
	{
		name = "Gain_in",
		min = 0,
		max = 5,
		default = 1,
		changed = function(val)
			gain_in = val
		end,
	},
	{
		name = "Gain",
		min = 0,
		max = 8,
		default = 1,
		changed = function(val)
			gain = val
		end,
	},
	{
		name = "bias",
		min = 0,
		max = 3,
		default = 0,
		changed = function(val)
			bias = val
		end,
	},
	{
		name = "pitch",
		min = 10,
		max = 100,
		default = 0,
		changed = function(val)
			f = 2 ^ ((val - 20) / 12) * 261.625565 / 44100.0

			print(f)
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
				for j = 1, size do
					w[i][j] = 0
					if math.random() < sparse then
						-- local idx = i + j * size + val
						w[i][j] = math.random() - 0.5
					end
				end
			end
		end,
	},
})

--params.resetToDefaults()
