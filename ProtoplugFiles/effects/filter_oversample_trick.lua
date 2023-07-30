-- for completely linear filters, we can mitigate high frequency "cramping" by oversampling
-- since we are not concerned about aliasing, we can skip the upsampling filter and just pass zero-stuffed samples
-- the downsampling can be done properly, or with a simple averaging
-- the latter has the nice property that the whole system does not introduce any latency

require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")
local Downsampler = require("include/dsp/downsampler_31")

local gain = 0

local freq = 440
local res = 0.7

local naive = false

local filters = {}

stereoFx.init()
function stereoFx.Channel:init()
	self.filter = Filter({ type = "eq", f = freq, gain = gain, Q = res })
	self.downsampler = Downsampler()

	table.insert(filters, self.filter)
end

function updateFilters()
	for i, v in ipairs(filters) do
		local freq2 = freq
		if not naive then
			freq2 = freq / 2
		end
		v.update({ f = freq2, gain = gain, Q = res })
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local inp = samples[i]

		local out

		if naive then
			out = self.filter.process(inp)
		else
			local u1 = self.filter.process(inp * 2)
			local u2 = self.filter.process(0)

			-- downsampler
			--out = self.downsampler.tick(u1, u2)

			-- averaging
			out = (u1 + u2) * 0.5
		end

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "freq",
		min = 0,
		max = 1,
		changed = function(val)
			freq = 20 * math.exp(math.log(1000) * val)
			print(freq)
			updateFilters()
		end,
	},
	{
		name = "q",
		min = 0.1,
		max = 10,
		changed = function(val)
			res = val
			updateFilters()
		end,
	},
	{
		name = "gain",
		min = -18,
		max = 18,
		changed = function(val)
			gain = val
			updateFilters()
		end,
	},

	{
		name = "naive",
		min = 0,
		max = 1,
		changed = function(val)
			naive = val > 0.5
			updateFilters()
		end,
	},
})
