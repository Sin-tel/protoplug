--[[
4 weakly coupled strings showing complex two-stage decay
]]

require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")
local Line = require("include/dsp/fdelay_line")

polyGen.initTracks(8)

local n_lines = 4

local pedal = false

local feedback = 0.0

local k_filter = 0.0
local hammer_stiffness = 1.0
local hammer_filter = 1.0
local hammer_noise = 0.2

local len_offset = { 1.0, 1.0, 1.0, 1.0 }

local function getLen(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return 44100 / f
end

function polyGen.VTrack:init()
	self.hammer = 1.0
	self.prev = 0.0
	self.len_base = 100.0
	self.feedback = 0.0
	self.lp = Filter({ type = "lp", f = 1000, Q = 0.7 })
	self.hp = Filter({ type = "hp", f = 20, Q = 0.7 })
	self.k_filter = 0.0
	self.delays = {}
	self.filter = {}
	for i = 1, n_lines do
		self.delays[i] = Line(2000)
		self.filter[i] = 0
	end
end

function processMidi(msg)
	if msg:isControl() then
		if msg:getControlNumber() == 64 then
			pedal = msg:getControlValue() ~= 0
		end
	end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	for i = 0, smax do
		local s = 0
		if self.hammer < 1.0 then
			self.hammer = self.hammer + self.hammer_f
			s = (math.sin(math.pi * self.hammer) ^ 4) * self.vel

			s = s * ((1.0 - hammer_noise) + hammer_noise * (math.random() - 0.5))
		end

		s = self.lp.process(s)
		s = self.hp.process(s)

		for k = 1, n_lines do
			local d = self.delays[k].goBack(self.len_base * len_offset[k])
			-- one pole lowpass
			local v = self.filter[k] + (d - self.filter[k]) * self.k_filter
			self.filter[k] = v
		end

		local f1 = self.feedback
		if self.released and not pedal then
			f1 = self.f_release
		end

		local w = { self.filter[1], self.filter[2], self.filter[3], self.filter[4] }

		local h = {
			0.999921917241 * w[1] + 0.004133082330 * w[2] - 0.011248083454 * w[3] - 0.003543680192 * w[4],
			-0.004032828150 * w[1] + 0.999955211665 * w[2] + 0.008396591821 * w[3] + 0.001675770479 * w[4],
			0.011304152548 * w[1] - 0.008360771327 * w[2] + 0.999881951397 * w[3] + 0.006196523895 * w[4],
			0.003480208689 * w[1] - 0.001609284643 * w[2] - 0.006249890784 * w[3] + 0.999973118246 * w[4],
		}

		for k = 1, n_lines do
			local v = h[k]
			local sd = v * f1
			if k == 1 then
				sd = sd * 0.985
				sd = sd + s
			end
			self.delays[k].push(sd)
		end

		samples[0][i] = samples[0][i] + h[1] + h[2] + 0.8 * h[3] + h[4]
		samples[1][i] = samples[1][i] + h[1] + 0.8 * h[2] + h[3] + h[4]
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.released = true
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.vel = 2 ^ ((vel - 127) / 30)

	self.hammer = 0
	self.released = false
	self.pitch = self.note
	self.len_base = getLen(self.pitch)

	self.hammer_f = hammer_stiffness / self.len_base
	self.hammer_f = self.hammer_f * (1.0 + 0.3 * self.vel)

	self.feedback = math.pow(feedback, self.len_base / 100)
	self.f_release = math.pow(feedback, self.len_base / 5)

	local freq = 44100 / self.len_base
	self.lp.update({ f = freq * hammer_filter })

	self.k_filter = math.pow(k_filter, self.len_base / 180.0)
end

params = plugin.manageParams({
	{
		name = "decay",
		min = 0.7,
		max = 1,
		changed = function(val)
			feedback = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	{
		name = "filter",
		min = 0,
		max = 1,
		changed = function(val)
			k_filter = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	{
		name = "hammer stiffnes",
		min = 0.5,
		max = 2,
		changed = function(val)
			hammer_stiffness = val
		end,
	},
	{
		name = "hammer noise",
		min = 0,
		max = 1,
		changed = function(val)
			hammer_noise = val
		end,
	},
	{
		name = "hammer filter",
		min = 1,
		max = 10,
		changed = function(val)
			hammer_filter = val
		end,
	},
	{
		name = "f2",
		min = 0.999,
		max = 1.001,
		changed = function(val)
			len_offset[2] = 1 / val
		end,
	},
	{
		name = "f3",
		min = 0.999,
		max = 1.001,
		changed = function(val)
			len_offset[3] = 1 / val
		end,
	},
	{
		name = "f4",
		min = 0.999,
		max = 1.001,
		changed = function(val)
			len_offset[4] = 1 / val
		end,
	},
})
