require("include/protoplug")
local svf = require("include/dsp/skf2")
local Upsampler = require("include/dsp/upsampler_11")
local Downsampler = require("include/dsp/downsampler_31")
local cbFilter = require("include/dsp/cookbook filters")

local gain = 0

local freq = 0.5
local res = 1

local db_to_exp = math.log(10) / 20

local filters = {}

local bias = 0.1

stereoFx.init()
function stereoFx.Channel:init()
	self.s = 0

	self.filter = svf.new()
	self.filter.update(0.5, 10)

	table.insert(filters, self.filter)
	self.upsampler = Upsampler()
	self.downsampler = Downsampler()
	
	self.high = cbFilter({ type = "hp", f = 5, gain = 0, Q = 0.7 })
end

function stereoFx.Channel:tick(u)
	return self.filter.process(gain*u + bias)/gain -bias
end


function updateFilters()
	for i, v in ipairs(filters) do
		v.update(freq, res)
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		local u1, u2 = self.upsampler.tick(s)

		u1 = self:tick(u1)
		u2 = self:tick(u2)

		local out = self.downsampler.tick(u1, u2)
		
		--out = self.high.process(out)

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "freq",
		min = 0,
		max = 1,
		changed = function(val)
			freq = 20 * math.exp(math.log(1000) * val) / 88200
			updateFilters()
		end,
	},
	{
		name = "resonance",
		min = 0.0,
		max = 2,
		changed = function(val)
			res = val
			updateFilters()
		end,
	},
	{
		name = "gain",
		min = -3,
		max = 3,
		changed = function(val)
			gain = math.exp(val)
		end,
	},
	{
		name = "bias",
		min = 0,
		max = 0.5,
		changed = function(val)
			bias = val
		end,
	},
	
})
