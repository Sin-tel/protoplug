--[[
chaos in a leaking faucet
time between drips is modeled with a logistic map
--]]

require("include/protoplug")

t = 0
r = 1
speed = 1

state = 0.1
interval = 0

function plugin.processBlock(s, smax)
	for i = 0, smax do
		local out = 0
		t = t + 1
		if t > interval then
			t = t - interval

			state = r * state * (1 - state)
			interval = (4 - r) * 50000 * (1 - state) / speed

			out = (4 - r) / (4.2 - r)
		end
		s[0][i] = out
		s[1][i] = out
	end
end

params = plugin.manageParams({
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	{
		name = "Open tap",
		min = 2.8,
		max = 3.999,
		default = 0,
		changed = function(val)
			r = val
		end,
	},
	{
		name = "Speed",
		min = 0.1,
		max = 2.1,
		default = 1,
		changed = function(val)
			speed = val
		end,
	},
})
