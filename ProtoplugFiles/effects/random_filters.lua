require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

local n = 64
stereoFx.init()
function stereoFx.Channel:init()
	self.s = 0

	self.f = {}
	for i = 1, n do
		local f = math.exp(math.random() * 6 - 6) * 17000
		-- local f = math.random() * 17000 + 100
		self.f[i] = Filter({ type = "bp", f = f, gain = 0, Q = 4 })
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]
		local out = 0
		for k = 1, n do
			out = out + self.f[k].process(s)
		end
		out = out / n

		samples[i] = out
	end
end

params = plugin.manageParams({
	-- {
	-- 	name = "amp",
	-- 	min = 0,
	-- 	max = 2,
	-- 	changed = function(val)
	-- 		a = val
	-- 	end,
	-- },
})
