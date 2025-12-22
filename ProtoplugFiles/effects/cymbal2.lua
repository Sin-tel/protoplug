require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
-- local Filter = require("include/dsp/cookbook_svf")

local k_filter = 0.625
local balance = 1.0

local max_num = 16
local l = 8
local feedback = 0
local coupling = 1
local master_freq = 1
local master_freq_s = 1

local theta = 0

local delay_a = {}
local delay_b = {}
local len_b = {}
local len_a = {}
local filter_a = {}
local filter_b = {}
local filter_c = {}
for i = 1, max_num do
	delay_a[i] = Line(2000)
	delay_b[i] = Line(2000)

	filter_a[i] = 0
	filter_b[i] = 0
	filter_c[i] = 0

	len_a[i] = 1000
	len_b[i] = 1000
end

local function randomize(seed)
	math.randomseed(seed)
	for i = 1, max_num do
		len_a[i] = 100 * (10 ^ math.random())
		len_b[i] = 100 * (10 ^ math.random())
		-- len_b[i] = len_a[i] * 0.9
	end
end

function plugin.processBlock(samples, smax)
	for k = 0, smax do
		local input = samples[0][k]

		local s = input

		local tot1 = 0
		local tot2 = 0

		master_freq_s = master_freq_s * 0.99 + master_freq * 0.01

		for i = 1, l do
			local d1 = delay_a[i].goBack(len_a[i] * master_freq_s)
			local d2 = delay_b[i].goBack(len_b[i] * master_freq_s)

			-- RMSE
			-- local power = d1 * d1 + d2 * d2
			-- filter_c[i] = filter_c[i] + (power - filter_c[i]) * 0.1
			-- power = 0.1 * math.sqrt(filter_c[i])
			local power = 0.1 * math.sqrt(d1 * d1 + d2 * d2)

			local mc = math.cos(theta + power)
			local ms = math.sin(theta + power)

			local x1 = mc * d1 - ms * d2
			local x2 = ms * d1 + mc * d2

			-- one pole lowpass
			local v1 = filter_a[i] + (x1 - filter_a[i]) * k_filter
			local v2 = filter_b[i] + (x2 - filter_b[i]) * k_filter

			filter_a[i] = v1
			filter_b[i] = v2

			tot1 = tot1 + v1
			tot2 = tot2 + v2
		end

		tot1 = tot1 / l
		tot2 = tot2 / l

		local f1 = feedback
		local f2 = coupling * 2 * feedback

		for i = 1, l do
			local v1 = filter_a[i]
			local v2 = filter_b[i]

			local ds1 = s + v1 * f1 - tot1 * f2
			local ds2 = s + v2 * f1 - tot2 * f2

			delay_a[i].push(ds1)
			delay_b[i].push(ds2)
		end

		local signal1 = tot1
		local signal2 = tot2

		samples[0][k] = signal1
		samples[1][k] = signal2
	end
end

local params = plugin.manageParams({
	{
		name = "number",
		min = 1,
		max = max_num,
		type = "int",
		changed = function(val)
			l = val
		end,
	},
	{
		name = "filter",
		min = 0,
		max = 1,
		changed = function(val)
			k_filter = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	{
		name = "feedback",
		min = 0,
		max = 1,
		changed = function(val)
			feedback = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	{
		name = "frequency",
		min = 0,
		max = 4,
		changed = function(val)
			master_freq = (2 ^ -val)
			print(master_freq)
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
	{
		name = "theta",
		min = 0,
		max = 1,
		changed = function(val)
			theta = val * math.pi
		end,
	},
})
