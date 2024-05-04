require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
-- local Filter = require("include/dsp/cookbook_svf")

local k_filter = 0.625
local balance = 1.0

local max_num = 50
local l = 8
local feedback = 0
local coupling = 1
local master_freq = 1

local delays = {}
local len = {}
local filter = {}
for i = 1, max_num do
	delays[i] = Line(2000)

	filter[i] = 0

	len[i] = math.random() * 1400 + 500
end

local prev = 0

local function randomize()
	for i = 1, max_num do
		local x = math.random()
		x = 100 / x
		if x < 100 then
			x = 100
		end
		if x > 1900 then
			x = 1900
		end
		len[i] = x
		print(len[i])
	end
end

function plugin.processBlock(samples, smax)
	for k = 0, smax do
		local input = samples[0][k]

		local s = input

		local tot = 0

		local u = -prev * 2.0

		--u = math.max(0, u)*12

		-- softmax
		u = u + math.sqrt(u * u + 0.3)

		for i = 1, l do
			local d = delays[i].goBack(len[i] * master_freq - u)

			-- one pole lowpass
			local v = filter[i] + (d - filter[i]) * k_filter

			filter[i] = v

			tot = tot + v
		end

		tot = tot / l

		if tot < -0.2 then
			tot = (tot + 0.2) * 0.5 - 0.2
		end

		prev = tot

		local f1 = feedback
		local f2 = coupling * 2 * feedback

		for i = 1, l do
			local v = filter[i]

			local ds = s + v * f1 - tot * f2

			delays[i].push(ds)
		end

		local signal = tot

		signal = input * (1.0 - balance) + signal * balance

		samples[0][k] = signal
		samples[1][k] = signal
	end
end

local params = plugin.manageParams({
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
		min = 0.1,
		max = 1,
		changed = function(val)
			master_freq = val
		end,
	},
	{
		name = "randomize",
		min = 0,
		max = 1,
		changed = function(val)
			randomize()
		end,
	},
})
