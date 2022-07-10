--[[
simulate slinky delay with characteristic frequency sweep
]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/delay_line")

local kap = 0.625
local l = 100
local len = 20
local feedback = 0
local time = 1

local maxn = 400

filters = {}

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

local function genFreq()
	--return  300*math.exp(math.log(20)*math.random());
	return 50 + 5000 * math.random()
end

function stereoFx.Channel:init()
	-- create per-channel fields (filters)
	self.ap = {}
	self.len = {}
	self.k = {}
	for i = 1, maxn do
		self.ap[i] = cbFilter({
			type = "ap",
			f = 200 * math.exp(math.log(10) * math.random()),
			gain = 0,
			Q = 1.7,
		})
		table.insert(filters, { filter = self.ap[i], f1 = genFreq(), f2 = genFreq() })

		self.len[i] = math.random()
		self.k[i] = math.random()
	end
	self.time = 0
	self.last = 0

	self.delay = Line(20000)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		--self.time = self.time + 1/44100

		local input = samples[i]

		local s = input - softclip(self.delay.goBack_int(18000 * time)) * feedback --+ 0.0001*(math.random()-0.5)

		for i = 1, l do
			s = self.ap[i].process(s)
		end

		local signal = s -- input*(kap^l)
		self.delay.push(signal)

		samples[i] = input * (1.0 - balance) + signal * balance
	end
end

local function updateFilters(a)
	for _, f in pairs(filters) do
		f.filter.update({
			--type 	= "ap";
			--f 		= 300*math.exp(math.log(20)*math.random());
			f = f.f1 * a + f.f2 * (1 - a),
			--Q 		= 1.7;
		})
	end
end

local function setQ(q)
	for _, f in pairs(filters) do
		f.filter.update({
			--type 	= "ap";
			--f 		= 500*math.exp(math.log(10)*math.random());
			Q = q,
		})
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
		name = "iter",
		min = 0,
		max = maxn,
		type = "int",
		changed = function(val)
			l = val
		end,
	},
	--[[	{
		name = "kap";
	    min = 0;
		max = 6;
		changed = function(val) kap = 1-math.exp(-val) end;
	};]]
	{
		name = "feedback",
		min = 0,
		max = 1,
		changed = function(val)
			feedback = val
		end,
	},
	{
		name = "time",
		min = 0.01,
		max = 1,
		changed = function(val)
			time = val
		end,
	},
	{
		name = "Q",
		min = 0,
		max = 1,
		changed = function(val)
			setQ(0.3 + 200 * (val * val))
		end,
	},
	{
		name = "reseed",
		min = 0,
		max = 1,
		changed = function(val)
			updateFilters(val)
		end,
	},
})
