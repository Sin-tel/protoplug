--[[
12db/o 3 band crossover
doesnt actually work correctly!
]]
require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local f1 = 500
local f2 = 5000

local lp = {}
local hp = {}

local lp2 = {}
local hp2 = {}
local ap = {}

local kap = 0.5

local qf = 0.5

stereoFx.init()
function stereoFx.Channel:init()
	self.lp = cbFilter({
		type = "lp",
		f = 500,
		gain = 0,
		Q = qf,
	})
	table.insert(lp, self.lp)

	self.hp = cbFilter({
		type = "hp",
		f = 500,
		gain = 0,
		Q = qf,
	})
	table.insert(hp, self.hp)

	self.lp2 = cbFilter({
		type = "lp",
		f = 5000,
		gain = 0,
		Q = qf,
	})
	table.insert(lp2, self.lp2)

	self.hp2 = cbFilter({
		type = "hp",
		f = 5000,
		gain = 0,
		Q = qf,
	})
	table.insert(hp2, self.hp2)

	self.ap = 0
	--[[cbFilter({
		type 	= "ap";
		f 		= 5000;
		gain 	= 0;
		Q 		= qf;
	})
	table.insert(ap,self.ap)]]
end

function updateFilters()
	for i, v in ipairs(lp) do
		v.update({ f = f1, Q = qf })
	end
	for i, v in ipairs(hp) do
		v.update({ f = f1, Q = qf })
	end

	for i, v in ipairs(lp2) do
		v.update({ f = f2, Q = qf })
	end
	for i, v in ipairs(hp2) do
		v.update({ f = f2, Q = qf })
	end

	kap = f2 / 44100

	--[[for i,v in ipairs(ap) do
        v.update({f = f2, Q = qf})
    end]]
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		local lps = self.lp.process(s)
		local hps = -self.hp.process(s)

		--local low = self.ap.process(lps)
		--[[local d = self.ap
		local v = lps + kap * d
		local low = kap*v - d
		self.ap = v
		low = - low]]

		local low = lps

		local mid = self.lp2.process(hps)
		local high = -self.hp2.process(hps)

		local out = low + mid + high

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "f1",
		min = 0,
		max = 1,
		changed = function(val)
			f1 = 50 * math.exp(math.log(20) * val)
			updateFilters()
		end,
	},
	{
		name = "f2",
		min = 0,
		max = 1,
		changed = function(val)
			f2 = 2000 * math.exp(math.log(10) * val)
			updateFilters()
		end,
	},
})
