--[[
Tilt the whole spectrum by some slope
(e.g. turn white noise into pink noise using a -3db/o slope)
]]

require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

local f1 = 20 * math.sqrt(10)
local f2 = 200
local f3 = 200 * math.sqrt(10)
local f4 = 2000
local f5 = 2000 * math.sqrt(10)

local q = 0.5

filters = {}

stereoFx.init()
function stereoFx.Channel:init()
	self.f1 = Filter({ type = "tilt", f = f1, gain = 0, Q = q })
	self.f2 = Filter({ type = "tilt", f = f2, gain = 0, Q = q })
	self.f3 = Filter({ type = "tilt", f = f3, gain = 0, Q = q })
	self.f4 = Filter({ type = "tilt", f = f4, gain = 0, Q = q })
	self.f5 = Filter({ type = "tilt", f = f5, gain = 0, Q = q })

	table.insert(filters, self.f1)
	table.insert(filters, self.f2)
	table.insert(filters, self.f3)
	table.insert(filters, self.f4)
	table.insert(filters, self.f5)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		s = self.f1.process(s)
		s = self.f2.process(s)
		s = self.f3.process(s)
		s = self.f4.process(s)
		s = self.f5.process(s)

		samples[i] = s * g_fact
	end
end

function updateFilters()
	for i, v in ipairs(filters) do
		v.update({ gain = gain })
	end
end

params = plugin.manageParams({
	{
		name = "slope (dB/oct)",
		min = -12,
		max = 12,
		changed = function(val)
			-- filters are spaced by half-decades
			-- 6db/o ~ 20db/decade
			gain = 10 * val / 6

			-- some heuristic overall gain
			g_fact = 10 ^ (-math.abs(val) / 10)
			print(g_fact)
			updateFilters()
		end,
	},
})
