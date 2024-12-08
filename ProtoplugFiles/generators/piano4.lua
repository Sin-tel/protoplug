--[[
another attempt at piano
]]

require("include/protoplug")

local Line = require("include/dsp/fdelay_line")
local cbFilter = require("include/dsp/cookbook_svf")

polyGen.initTracks(24)

local release = 0.99
local decay = 0.99

local position = 0.2

local pedal = false

local tun_m = 1
local tun_o = 0

-- local apf = 8000

function polyGen.VTrack:init()
	-- create per-track fields here

	self.pitch = 0
	self.vel = 0
	self.finished = true

	self.len = { 20, 20, 20 }

	self.position = 0.132

	self.integrate = 0

	self.decay = 0.99
	self.release = 0.99

	self.hammer_t = 0.0
	self.hammer_d = 1.0
	self.hammer_t1 = 1.0
	self.hammer_f = 1.0

	self.n_delays = 1

	self.delay = {}
	self.delay[1] = Line(1024)
	self.delay[2] = Line(1024)
	self.delay[3] = Line(1024)
	self.delay_hammer = Line(1024)

	self.h_t = 0

	self.ap = {
		cbFilter({
			type = "ap",
		}),
		cbFilter({
			type = "ap",
		}),
		cbFilter({
			type = "ap",
		}),
	}

	self.loop_filter = {
		cbFilter({
			type = "hs",
		}),
		cbFilter({
			type = "hs",
		}),
		cbFilter({
			type = "hs",
		}),
	}

	self.hammerfilter = cbFilter({
		type = "lp",
		f = 10,
		Q = 0.7,
	})
	self.hammerfilter2 = cbFilter({
		type = "lp",
		f = 10,
		Q = 0.7,
	})
	self.hammerfilter3 = cbFilter({
		type = "lp",
		f = 10,
		Q = 0.7,
	})

	self.dc_kill = cbFilter({
		type = "hp",
		f = 100,
		Q = 0.5,
	})
end

function processMidi(msg)
	if msg:isControl() then
		if msg:getControlNumber() == 64 then
			pedal = msg:getControlValue() ~= 0
		end
	end
end

-- C2-C7 offset in cents
local tun_table = { 93.0, 64.0, 80.0, 132.0, 221.0, 322.0 }

local function getFreq(note)
	local t = (note / 12) - 2
	if t <= 1.0 then
		t = 1.0
	end
	if t >= 5.999 then
		t = 5.999
	end
	local t_index = math.floor(t)
	local t_frac = t - t_index

	local t_c = (1.0 - t_frac) * tun_table[t_index] + t_frac * tun_table[t_index + 1]
	local f_c = 2 ^ (t_c / 1200)

	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return (f * f_c / 44100)
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	for i = 0, smax do
		local nse = math.random() - 0.5
		local nse2 = math.random() - 0.5
		local s = 0

		local w = 0
		local t2 = self.hammer_t1 * 2
		if t2 < 1.0 then
			local hs = 0.5 - 0.5 * math.cos(2 * math.pi * self.hammer_t1)
			s = s + 1.0 * nse * hs * self.vel
		end

		s = self.hammerfilter.process(s)
		if self.hammer_t1 < 1.0 then
			local hs = 0.5 - 0.5 * math.cos(2 * math.pi * (1.0 - self.hammer_t1) ^ 3)
			s = s + hs * self.vel
		end
		s = self.hammerfilter2.process(s)
		s = self.hammerfilter3.process(s)
		s = s + 0.00003 * nse2 * self.hammer_t

		self.hammer_t1 = self.hammer_t1 + self.hammer_f

		s = self.dc_kill.process(s)

		local hs = self.delay_hammer.goBack(self.len[1] * self.position)
		self.delay_hammer.push(s)
		s = s - hs

		self.hammer_t = self.hammer_t * self.hammer_d

		if self.finished and not pedal then
			self.decay = 0.99 * self.decay + 0.01 * self.release
		end
		local damp = self.decay

		local string_s = 0
		for k = 1, self.n_delays do
			local ds = self.delay[k].goBack(self.len[k] * (1 / tun_m) + tun_o)
			ds = ds * damp
			ds = self.ap[k].process(ds)
			ds = self.loop_filter[k].process(ds)
			self.delay[k].push(ds + s)
			string_s = string_s + ds
		end
		string_s = string_s / self.n_delays

		-- local out = s
		local out = string_s + s

		samples[0][i] = samples[0][i] + out -- left
		samples[1][i] = samples[1][i] + out -- right
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.finished = true
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.finished = false

	local f = getFreq(note)
	print(note, 44100 * f)

	self.n_delays = 3
	self.len[1] = 1.0001 / f
	self.len[2] = 1.0003 / f
	self.len[3] = 0.9996 / f

	if note <= 38 then
		self.n_delays = 1
		self.len[1] = 1.0 / f
	elseif note <= 50 then
		self.n_delays = 2
		self.len[1] = 0.9998 / f
		self.len[2] = 1.0002 / f
	end

	local v = 0.05 * math.exp(-math.log(0.05) * (vel / 127) ^ 0.8)

	local v_o = math.max(0, (60 - note) / 32)
	self.vel = v + v_o

	self.position = position

	self.hammer_t = v
	-- self.hammer_d = math.exp(-0.0000147 * note)
	self.hammer_d = math.pow(0.5, f)
	self.hammer_t1 = 0.0
	local fpo = 3.5 * (1.0 - note / 150)
	-- local fpo = 1.0
	self.hammer_f = f * (0.1 + v * 0.5) * fpo

	self.decay = math.pow(0.99, 0.001 / f)
	self.release = math.pow(release, 0.003 / f)

	self.hammerfilter.update({
		f = 44100 * f * 4.0,
		Q = 0.7,
	})
	-- local lpo = 3 + v * 10 - (note - 60) / 10
	local lpo = 1 + v * 20 - (note - 60) / 30
	-- local lpf = 44100 * f * lpo
	local lpf = 200 * lpo
	self.hammerfilter2.update({
		f = lpf,
		Q = 0.7,
	})
	self.hammerfilter3.update({
		f = lpf,
		Q = 0.7,
	})

	local w = note / 127
	local apo = 1 / (0.39 - 1.73 * w + 2.23 * w * w)
	local apf = 44100 * f * apo
	print(apo, apf)
	local apq = 0.45
	self.ap[1].update({ f = apf, Q = apq })
	self.ap[2].update({ f = apf, Q = apq })
	self.ap[3].update({ f = apf, Q = apq })

	local fgain = -0.002 / f
	-- local fgain = -2.0

	local fq = 0.77
	local ff = 4000
	self.loop_filter[1].update({ gain = fgain, f = ff, Q = fq })
	self.loop_filter[2].update({ gain = fgain, f = ff, Q = fq })
	self.loop_filter[3].update({ gain = fgain, f = ff, Q = fq })
end

params = plugin.manageParams({
	{
		name = "decay",
		min = 4,
		max = 12,
		default = 6.2,
		changed = function(val)
			decay = 1.0 - math.exp(-val)
		end,
	},
	{
		name = "release",
		min = 2,
		max = 10,
		default = 3,
		changed = function(val)
			release = 1.0 - math.exp(-val)
		end,
	},
	{
		name = "Position",
		min = 0,
		max = 0.5,
		default = 0.21,
		changed = function(val)
			position = val
		end,
	},
	{
		name = "Tune master",
		min = -400,
		max = 400,
		default = 0,
		changed = function(val)
			tun_m = 2 ^ (val / 1200)
		end,
	},
	{
		name = "Tune offset",
		min = -10,
		max = 10,
		default = -1.8,
		changed = function(val)
			tun_o = val
		end,
	},

	-- {
	-- 	name = "allpass",
	-- 	min = 2,
	-- 	max = 4,
	-- 	changed = function(val)
	-- 		apf = 10 ^ val
	-- 		print(apf)
	-- 	end,
	-- },
})

-- params.resetToDefaults()
