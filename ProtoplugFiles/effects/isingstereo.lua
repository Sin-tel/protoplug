require("include/protoplug")
local ffi = require("ffi")

local temp = 1

local n = 2048
local l = 16

local iter = 1

local amp = 1

state = ffi.new("int[?]", n)

for i = 0, n - 1 do
	state[i] = 1
	if math.random() < 0.5 then
		state[i] = -state[i]
	end
end

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local b1 = samples[0][i]
		local b2 = samples[1][i]

		local exp = math.exp
		local rand = math.random

		for j = 0, iter do
			local ind = rand(n) - 1
			local s = state[ind]
			--sum = sum + s
			local b = b2
			if ind < n / 2 then
				b = b1
			end

			local i1 = ind - 1
			local i2 = ind + 1
			if i1 < 0 then
				i1 = n - 1
			end
			if i2 >= n then
				i2 = 0
			end

			local e = -s * (state[i1] + state[i2] + amp * b)

			if e < 0 then
				local h = exp(e * temp)
				if rand() < h then
					state[ind] = -s
				end
			else
				state[ind] = -s
			end
		end

		local sum1 = 0
		local sum2 = 0
		for j = 0, n - 1 do
			local s = state[j]
			if j < n / 2 then
				sum1 = sum1 + s
			else
				sum2 = sum2 + s
			end
		end

		local signal1 = 2 * sum1 / n
		local signal2 = 2 * sum2 / n

		samples[0][i] = signal1
		samples[1][i] = signal2
	end
end

params = plugin.manageParams({

	{
		name = "T",
		min = 0,
		max = 3,
		changed = function(val)
			temp = 1 / val
		end,
	},

	{
		name = "iter",
		min = 0,
		max = 200,

		changed = function(val)
			iter = val
		end,
	},
	{
		name = "amp",
		min = 0.5,
		max = 5,

		changed = function(val)
			amp = val
		end,
	},
	{
		name = "print",
		changed = function(val)
			print("=======")
			for i = 0, n - 1 do
				print(state[i])
			end
		end,
	},
})
