--[[
another attempt at piano
]]

require("include/protoplug")

local Line = require("include/dsp/fdelay_line")
local cbFilter = require("include/dsp/cookbook filters")

local release = 0.99
local decay = 0.99

local start_vel = 1.0

local position = 0.2

local stiffness = 10

polyGen.initTracks(24)

local pitchbend = 0

local pedal = false

local tun_m = 1
local tun_o = 0

local string_load = 2.0

local alpha = 0.2

local dt = 0.05

function polyGen.VTrack:init()
	-- create per-track fields here

	self.f = 1
	self.pitch = 0
	self.vel = 0
	self.finished = true

	self.position = 0.2

	self.integrate = 0

	self.decay = 0.99
	self.release = 0.99

	self.stiffness = 1.0

	self.delayL = Line(1024)
	self.delayR = Line(1024)
	self.delayL2 = Line(1024)
	self.delayR2 = Line(1024)

	self.hf_prev = 0

	self.exponent = 2.5

	self.hammer_x = 0
	self.hammer_v = 0
	self.hammer_ef = 0 -- external force

	self.p_prev = 0.0

	self.kap = 0.5
	self.ap = cbFilter({
		type = "ap",
		f = 2000,
		gain = 0,
		Q = 0.7,
	})
	self.ap2 = cbFilter({
		type = "ap",
		f = 2000,
		gain = 0,
		Q = 0.7,
	})

	self.lp = cbFilter({
		type = "hs",
		f = 4000,
		gain = -6,
		Q = 0.7,
	})

	self.noisefilter = cbFilter({
		type = "lp",
		f = 1200,
		gain = 0,
		Q = 0.7,
	})

	self.mutefilter = cbFilter({
		type = "hs",
		f = 1000,
		gain = -1,
		Q = 0.7,
	})

	self.hammerfilter = cbFilter({
		type = "hp",
		f = 10,
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

local function hammer_force(x, exp)
	local hf = 0
	if x > 0 then
		hf = x
		hf = math.pow(hf, exp)
	end
	return hf
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	for i = 0, smax do
		local nse = math.random() - 0.5

		nse = self.noisefilter.process(nse)

		local len = 1 / (self.f * tun_m) + tun_o
		-- local len2 = 1 / ((self.f * 1.001) * tun_m) + tun_o
		local len2 = 1 / ((self.f + 0.000002) * tun_m) + tun_o

		local pos = self.position
		local pos2 = pos + 0.03

		local right = -self.delayR.goBack((1 - pos) * len)
		local left = -self.delayL.goBack(pos * len)

		local right2 = -self.delayR2.goBack((1 - pos2) * len2)
		local left2 = -self.delayL2.goBack(pos2 * len2)

		right = self.ap.process(right)
		right2 = self.ap2.process(right2)
		-- left = self.lp.process(left)

		local s = left + right + left2 + right2
		self.integrate = self.integrate * 0.9999 + s

		local sx2 = self.integrate * string_load
		local sx1 = 0.5 * (self.hf_prev + sx2)
		self.hf_prev = sx2

		local hf1 = hammer_force(sx1 - self.hammer_x, self.exponent) * self.stiffness
		self.hammer_v = self.hammer_v + dt * hf1
		self.hammer_x = self.hammer_x + self.hammer_v

		local hf2 = hammer_force(sx2 - self.hammer_x, self.exponent) * self.stiffness
		self.hammer_v = self.hammer_v + dt * hf2
		self.hammer_x = self.hammer_x + self.hammer_v

		local hf = 0.5 * (hf1 + hf2)

		local dv = hf - self.p_prev
		self.p_prev = hf

		-- hf = hf * (1.0 + 0.2 * nse)
		hf = math.min(1, hf)
		hf = math.max(0, hf)

		-- self.hammer_ef = self.hammer_ef * 0.99
		-- if self.hammer_ef < 0.01 then
		-- 	self.hammer_ef = 0
		-- end

		-- local nr = self.mutefilter.process(right)

		local damp = self.decay
		if self.finished and not pedal then
			--damp = release
			-- right = nr * self.release
			right = right * self.release
			right2 = right2 * self.release
			hf = 0
		end

		-- local kr = 0.8
		-- local k = kr * math.max(0, s - self.hammer_x)
		-- k = self.hammerfilter.process(k)
		-- local k = self.hammerfilter.process(hf)

		local k = hf
		local s1 = -(left + right)
		local a = 1.0
		self.delayL.push(right * damp + k * (a + s1))
		self.delayR.push(left * damp + k * (a + s1))

		local s2 = -(left2 + right2)
		self.delayL2.push(right2 * damp + k * (a + s2))
		self.delayR2.push(left2 * damp + k * (a + s2))

		-- self.delayL.push(right * damp + k)
		-- self.delayR.push(left * damp + k)

		-- self.delayL2.push(right2 * damp + k)
		-- self.delayR2.push(left2 * damp + k)

		-- local out = left + right + left2 + right2

		local out = self.hammerfilter.process(self.integrate)
		-- local out = left2 + right2

		local sample = out * dt
		-- local sample = hf
		-- local sample = math.max(sx2 - self.hammer_x, 0)

		samples[0][i] = samples[0][i] + sample -- left
		samples[1][i] = samples[1][i] + sample -- right
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.finished = true
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.finished = false

	self.pitch = self.note
	self.f = getFreq(self.pitch + pitchbend)

	-- self.stiffness = 44100 * self.f ^ 2 * stiffness / 20
	-- self.stiffness = 44100 * self.f * stiffness / 440
	self.stiffness = stiffness

	--local v = vel/127
	local v = 2 ^ ((vel - 127) / 30)
	self.vel = v

	-- local v_mod = 4 / (1 + (note - 31) / 20)
	local v_mod = 1
	-- print(v_mod)

	self.integrate = 0.0

	self.hammer_x = 0.1
	self.hammer_v = -0.08 * v * start_vel * v_mod
	self.hammer_ef = 0.1 * v

	self.hf_prev = 0

	self.decay = math.pow(0.99, 0.001 / self.f)
	self.release = math.pow(release, 0.003 / self.f)

	-- local apf = 44100 * self.f * (11 - (note - 60) / 30)
	local apf = 44100 * self.f * 9
	-- local apf = 8000
	-- apf = math.min(18000, apf)
	self.ap.update({ f = apf, Q = 0.3 })
	self.ap2.update({ f = apf, Q = 0.3 })

	self.exponent = 1.4 + note / 60
	-- self.exponent = 2.5
	print(self.exponent)

	-- self.position = position + 0.05 * (math.random() - 0.5)
	-- self.position = 0.132 - math.max(note - 70, 0) / 700
	-- self.position = math.max(0.07, math.min(0.5, self.position))

	self.position = position
	self.position = math.max(0.01, math.min(0.5, self.position))

	local fgain = -0.002 / self.f

	self.lp.update({
		f = 4000,
		gain = fgain,
		Q = 0.7,
	})

	-- local lpf = 44100 * self.f * 0.5
	-- self.hammerfilter.update({
	-- 	f = lpf,
	-- 	Q = 0.7,
	-- })

	--print(self.position)

	--print(v)

	--print(0.005/self.f)
end

function getFreq(note)
	local n = note - 69
	local f = 440 * 2 ^ ((n * 1.002) / 12)
	return f / 44100
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
		name = "Stiffness",
		min = 0,
		max = 1.0,
		default = 10,
		changed = function(val)
			stiffness = val
		end,
	},

	{
		name = "Tune master",
		min = -0.1,
		max = 0.1,
		default = 0.0694,
		changed = function(val)
			tun_m = math.exp(val)
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

	{
		name = "hammer vel",
		min = 0,
		max = 2,
		changed = function(val)
			start_vel = val
		end,
	},

	{
		name = "string loading",
		min = 0,
		max = 2,
		changed = function(val)
			string_load = val
		end,
	},

	{
		name = "hammer mass",
		min = 1,
		max = 4,
		changed = function(val)
			dt = 1 / (10 ^ val)
			print(dt)
		end,
	},
})

-- params.resetToDefaults()
