--[[
20 pole phase with zero delay feedback path
]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local kap = 0.625
local l = 20
local feedback = 0

stereoFx.init()

function softclip(x)
	if x <= -1.5 then
		return -1
	elseif x >= 1.5 then
		return 1
	else
		return x - (4 / 27) * x * x * x
	end
end

function stereoFx.Channel:init()
	self.ap = {}
	self.len = {}
	self.k = {}
	for i = 1, l do
		self.ap[i] = 0
		self.k[i] = 0.95 + 0.05 * math.random()
	end
	self.time = 0
	self.last = 0

	self.fdbck = 0

	self.kap = 0.5

	self.hs = cbFilter({
		type = "hs",
		f = 7000,
		gain = -0.2,
		Q = 0.3,
	})
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local input = samples[i]

		self.kap = 0.999 * self.kap + 0.001 * kap

		local x = input

		-- compute feedback loop
		local k = -self.kap
		local k2 = (1.0 - k * k)

		local G = 1
		local S = 0

		for i = 1, l do
			G = G * k
			S = S * k + self.ap[i] * k2
		end

		local u = (x + feedback * S) / (1 - feedback * G)

		-- "cheap" nonlinear approach, no root solving or any of that
		u = softclip(u)

		-- update state
		for i = 1, l do
			local d = self.ap[i]
			local v = u - k * d

			u = k * v + d

			self.ap[i] = v
		end

		local signal = u

		samples[i] = (input * (1.0 - balance) + signal * balance)
	end
end

local function updateFilters(filters, args)
	for _, f in pairs(filters) do
		f.update(args)
	end
end

params = plugin.manageParams({
	{
		name = "Dry/Wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "kap",
		min = 0,
		max = 6,
		changed = function(val)
			kap = 1 - math.exp(-val)
		end,
	},
	{
		name = "feedback",
		min = -1.0,
		max = 1.0,
		changed = function(val)
			feedback = val
		end,
	},
})