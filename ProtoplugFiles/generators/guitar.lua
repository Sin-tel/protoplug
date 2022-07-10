--[[
physical model of a guitar

]]

require("include/protoplug")

local Line = require("include/dsp/fdelay_line")
local cbFilter = require("include/dsp/cookbook filters")

local release = 0.99
local decay = 0.99

local position = 0.2

polyGen.initTracks(24)

local pitchbend = 0

local pedal = false

local tun_m = 1
local tun_o = 0

local dt = 0.001

function polyGen.VTrack:init()
	-- create per-track fields here

	self.f = 1
	self.pitch = 0
	self.vel = 0
	self.finished = true

	self.position = 0.2

	self.decay = 0.99
	self.release = 0.99

	self.delayL = Line(1024)
	self.delayR = Line(1024)

	self.hammer_x = 0
	self.hammer_v = 0
	self.hammer_ef = 0 -- external force

	self.kap = 0.5
	self.ap = cbFilter({
		-- initialize filters with current param values
		type = "ap",
		f = 12000,
		gain = 0,
		Q = 0.7,
	})

	self.lp = cbFilter({
		-- initialize filters with current param values
		type = "hs",
		f = 4000,
		gain = -6,
		Q = 0.7,
	})

	self.noisefilter = cbFilter({
		-- initialize filters with current param values
		type = "bp",
		f = 1200,
		gain = 0,
		Q = 1.2,
	})

	self.mutefilter = cbFilter({
		-- initialize filters with current param values
		type = "hs",
		f = 1000,
		gain = -6,
		Q = 0.7,
	})
end

function processMidi(msg)
	if msg:isPitchBend() then
		local p = msg:getPitchBendValue()
		p = (p - 8192) / 8192
		pitchbend = p * 2
		for i = 1, polyGen.VTrack.numTracks do
			local vt = polyGen.VTrack.tracks[i]
			vt.f = getFreq(vt.pitch + pitchbend)
		end
	elseif msg:isControl() then
		if msg:getControlNumber() == 64 then
			pedal = msg:getControlValue() ~= 0
		end
		print(pedal)
	end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	for i = 0, smax do
		local nse = math.random() - 0.5

		nse = self.noisefilter.process(nse)

		local len = 1 / (self.f * tun_m) + tun_o

		local pos = self.position

		local right = -self.delayR.goBack((1 - pos) * len)
		local left = -self.delayL.goBack(pos * len)

		right = self.ap.process(right)

		left = self.lp.process(left)

		local s = right + left

		local hf = 0
		if s > self.hammer_x then
			local h = s - self.hammer_x

			local hv = (s - self.hammer_v) * dt

			local p = math.pow(h, 2.5)

			hf = 1 * p * (0.5 + 0.1 * hv)

			hf = hf * (1.0 + 0.2 * nse)

			hf = math.min(1, hf)
		end

		self.hammer_v = self.hammer_v + dt * (hf - 0.0 * self.hammer_ef)
		self.hammer_x = self.hammer_x + self.hammer_v

		--[[self.hammer_ef = self.hammer_ef*0.99 -- 0.99
		if self.hammer_ef < 0.01 then
			self.hammer_ef = 0
		end]]

		local nr = self.mutefilter.process(right)

		local damp = self.decay
		if self.finished and not pedal then
			--damp = release
			right = nr * self.release
		else
		end
		self.delayL.push(right * damp - hf)
		self.delayR.push(left * damp - hf)

		local out = left + right

		local sample = out * 0.1

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

	--local v = vel/127
	local v = (vel / 127) ^ 2
	v = v + 0.024

	--local v = 2^((vel-127)/30)

	self.vel = v

	self.hammer_x = 1
	self.hammer_v = -0.08 * v
	self.hammer_ef = 5 * v

	self.decay = math.pow(0.99, 0.001 / self.f)
	self.release = math.pow(0.9, 0.003 / self.f)

	local apf = 44100 * self.f * 7
	apf = math.min(18000, apf)
	self.ap.update({ f = apf, Q = 0.7 })

	self.position = position + 0.05 * (math.random() - 0.5)

	self.position = math.max(0.0, math.min(1.0, self.position))

	local fgain = -0.002 / self.f

	self.lp.update({
		f = 4000,
		gain = fgain,
		Q = 0.7,
	})

	--print(self.position)

	--print(v)

	--print(0.005/self.f)
end

function getFreq(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return f / 44100
end

function getBellFreq(note)
	local n = note - 69
	local f = 1200 * 2 ^ (n / 34)
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
})

params.resetToDefaults()
