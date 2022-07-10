--[[
Lorenz system
--]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local downsampler = require("include/dsp/downsampler")

local sigma = 10
local beta = 8 / 3
local rho = 28

local dt = 1 / 44100

stereoFx.init()
function stereoFx.Channel:init()
	self.x = 1
	self.y = 1
	self.z = 1

	self.high = cbFilter({ type = "hp", f = 20, gain = 0, Q = 0.7 })
	self.dsampler = downsampler()
	self.dsampler2 = downsampler()
end

function stereoFx.Channel:tick()
	local dx = sigma * (self.y - self.x)
	local dy = self.x * (rho - self.z) - self.y
	local dz = self.x * self.y - beta * self.z

	self.x = self.x + dx * dt + 0.00001 * math.random()
	self.y = self.y + dy * dt
	self.z = self.z + dz * dt

	return self.z
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		--local b = 10*samples[i]

		local u = self.dsampler2.tick(
			self.dsampler.tick(self:tick(), self:tick()),
			self.dsampler.tick(self:tick(), self:tick())
		)

		local out = self.high.process(u)

		samples[i] = out * 0.01
	end
end

params = plugin.manageParams({
	{
		name = "speed",
		min = 1,
		max = 7,
		default = 5,
		changed = function(val)
			dt = math.exp(val) / 44100
		end,
	},
	{
		name = "sigma",
		min = 0,
		max = 10,
		default = 10,
		changed = function(val)
			sigma = val
		end,
	},
	{
		name = "beta",
		min = 0,
		max = 3,
		default = 8 / 3,
		changed = function(val)
			beta = val
		end,
	},
	{
		name = "rho",
		min = 0,
		max = 28,
		default = 28,
		changed = function(val)
			rho = val
		end,
	},
})

params.resetToDefaults()
