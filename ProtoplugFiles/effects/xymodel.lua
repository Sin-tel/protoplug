require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local temp = 0

local n = 64
local l = 8

local iter = 1

local b = 0

local amp = 1
local amp2 = 1

state = {}
energy = {}

for i = 0, n - 1 do
	energy[i] = 0
	state[i] = math.random() * 2 * math.pi
end

function plugin.processBlock(samples, smax)
	local rand = math.random
	for i = 0, smax do
		b = samples[0][i]
		c = samples[1][i]

		for j = 0, n - 1 do
			local ind = j
			local s = state[ind]
			--sum = sum + s

			local i1 = ind - 1
			local i2 = ind + 1
			local i3 = ind - l
			local i4 = ind + l
			if i1 < 0 then
				i1 = n - 1
			end
			if i2 >= n then
				i2 = 0
			end
			if i3 < 0 then
				i3 = n - 1
			end
			if i4 >= n then
				i4 = 0
			end

			local f = 0.1
				* (
					-math.sin(s - state[i1])
					- math.sin(s - state[i2])
					- math.sin(s - state[i3])
					- math.sin(s - state[i4])
					+ math.cos(s - amp * b)
					+ math.sin(s - amp * c)
				)
			--local f = 0.1*(math.cos(s - amp*b) + math.sin(s - amp*c))
			state[ind] = s + f + temp * (rand() - 0.5)
		end

		local sum = 0
		local s2 = 0
		for j = 0, n - 1 do
			local s = state[j]
			sum = sum + math.sin(s)
			s2 = s2 + math.cos(s)
		end

		--state = newstate

		local signal = sum / n
		local sig2 = s2 / n

		samples[0][i] = signal
		samples[1][i] = sig2
	end
end

params = plugin.manageParams({

	{
		name = "T",
		min = 0.01,
		max = 3,
		changed = function(val)
			temp = val
		end,
	},
	{
		name = "print",
		changed = function(val)
			print("=======")
			for i = 0, n - 1 do
				print(state[i] % (2 * math.pi))
			end
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
		name = "amp stereo",
		min = 0.5,
		max = 5,

		changed = function(val)
			amp2 = val
		end,
	},
})
