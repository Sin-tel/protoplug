-- stochastic lowpass filter, good for adding signal-dependent noise

require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

local c = 0

local filters = {}

stereoFx.init()
function stereoFx.Channel:init()
	self.s = 0

	self.noise_filter = Filter({ type = "tilt", f = 800, gain = 6, Q = 0.4 })

	table.insert(filters, self.noise_filter)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local x = samples[i]

		local noise = math.random() - 0.5
		noise = self.noise_filter.process(noise) + 0.5

		local r = noise * 0.2 * c + (1 - c)
		self.s = self.s + r * (x - self.s)

		samples[i] = self.s
	end
end

local function updateFilters(filters, args)
	for _, f in pairs(filters) do
		f.update(args)
	end
end

params = plugin.manageParams({
	{
		name = "noise",
		min = 0,
		max = 8,
		changed = function(val)
			c = 1.0 - math.exp(-val)
			print(c)
		end,
	},
	{
		name = "noise color",
		min = -18,
		max = 18,
		default = 0,
		changed = function(val)
			updateFilters(filters, { gain = val })
		end,
	},
})
