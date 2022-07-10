require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/fdelay_line")

local balance = 1.0

local kap = 0.6 -- 0.625

local l1 = 2687
local l2 = 4349
local l3 = 5227
local l4 = 7547

local feedback = 0.4

local time = 1.0
local t_60 = 1.0

stereoFx.init()

function stereoFx.Channel:init()
	self.line1 = Line(8000)
	self.line2 = Line(8000)
	self.line3 = Line(8000)
	self.line4 = Line(8000)

	self.ap = {}
	self.apl = {}
	for i = 1, 4 do
		self.ap[i] = Line(800)
	end
	self.apl[1] = 53
	self.apl[2] = 103
	self.apl[3] = 719
	self.apl[4] = 389

	self.lfot = 0

	self.shelf1 = cbFilter({
		type = "hs",
		f = 8000,
		gain = -3,
		Q = 0.7,
	})

	self.time_ = 1.0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		self.lfot = self.lfot + 1 / 44100

		local mod = 1.0 + 0.005 * math.sin(5.35 * self.lfot)
		local mod2 = 1.0 + 0.008 * math.sin(3.12 * self.lfot)

		self.time_ = self.time_ - (self.time_ - time) * 0.001

		local input = samples[i]

		local s = input

		-- allpasses
		for i = 1, 4 do
			local d = self.ap[i].goBack_int(self.apl[i])
			local v = s - kap * d
			s = kap * v + d
			self.ap[i].push(v)
		end

		local ins = s

		local d1 = self.line1.goBack(l1 * self.time_ * mod)
		local d2 = self.line2.goBack(l2 * self.time_)
		local d3 = self.line3.goBack(l3 * self.time_ * mod2)
		local d4 = self.line4.goBack(l4 * self.time_)

		local gain = feedback * 0.5

		local s1 = self.shelf1.process(ins + (d1 + d2 + d3 + d4) * gain)

		self.line1.push(s1)
		self.line2.push(ins + (d1 - d2 + d3 - d4) * gain)
		self.line3.push(ins + (d1 + d2 - d3 - d4) * gain)
		self.line4.push(ins + (d1 - d2 - d3 + d4) * gain)

		local ss = 0.25 * (d1 + d2 + d3 + d4)

		local signal = ss

		samples[i] = input * (1.0 - balance) + signal * balance
	end
end

function setFeedback(t)
	-- print(t)
	if t then
		t_60 = t
	end
	feedback = 10 ^ (-(60 * 4000 * time) / (t_60 * 44100 * 20))
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
		name = "Size",
		min = 0.5,
		max = 1,
		changed = function(val)
			time = val
			setFeedback()
		end,
	},
	{
		name = "Decay Time",
		min = 0,
		max = 1,
		changed = function(val)
			setFeedback(2 ^ (8 * val - 4))
		end,
	},
})
