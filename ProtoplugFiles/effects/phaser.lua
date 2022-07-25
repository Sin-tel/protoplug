--[[
20 pole phase with naive feedback path
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

		local s = softclip(input + self.fdbck * feedback)

		self.kap = 0.999 * self.kap + 0.001 * kap

		--local mod = math.abs(s)*0.01

		for i = 1, l do
			--local k = math.max(0, self.kap * self.k[i] - math.abs(s)*0.001)
			local k = self.kap * self.k[i]
			local d = self.ap[i]
			local v = s + k * d

			s = k * v - d

			self.ap[i] = v
		end

		local signal = s

		self.fdbck = self.hs.process(s)

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
