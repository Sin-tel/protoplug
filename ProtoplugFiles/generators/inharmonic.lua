--[[
4 strongly coupled strings
]]

require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
local Filter = require("include/dsp/cookbook_svf")

polyGen.initTracks(8)

local n_lines = 4

local pedal = false

local bloom = 0.0
local rattle = 0.0

local feedback = 0.0
local fb_sign = 1.0

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
			s = (math.sin(math.pi * self.hammer) ^ 2) * self.vel

			s = s * ((1.0 - hammer_noise) + hammer_noise * (math.random() - 0.5))
		end

		s = self.lp.process(s)
		s = self.hp.process(s)

		local tot = 0

		local u = -self.prev
		-- u = u + math.sqrt(u * u + 0.3)
		u = math.abs(u)
		-- u = math.max(0, u)
		u = u * bloom * 0.005

		for k = 1, n_lines do
			local d = self.delays[k].goBack(self.len_base * len_offset[k] * (1.0 - u) - 1.0)
			-- one pole lowpass
			local v = self.filter[k] + (d - self.filter[k]) * self.k_filter
			self.filter[k] = v
			tot = tot + v
		end

		tot = tot / n_lines

		local f1 = self.feedback
		if self.released and not pedal then
			f1 = self.f_release
		end
		local f2 = 2.0 * f1

		if tot < rattle then
			-- NOTE: this is wrong but it sounds cool
			tot = (tot + rattle) * f1 - rattle
		end

		self.prev = tot

		for k = 1, n_lines do
			local v = self.filter[k]
			local sd = s + v * f1 - tot * f2
			self.delays[k].push(fb_sign * sd)
		end

		local out_s = tot

		samples[0][i] = samples[0][i] + out_s
		samples[1][i] = samples[1][i] + out_s
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
		name = "bloom",
		min = 0,
		max = 1,
		changed = function(val)
			bloom = val
		end,
	},
	{
		name = "rattle",
		min = 0,
		max = 1,
		changed = function(val)
			rattle = val - 1.0
		end,
	},
	{
		name = "f2",
		min = 1,
		max = 4,
		changed = function(val)
			len_offset[2] = 1 / val
		end,
	},
	{
		name = "f3",
		min = 1,
		max = 4,
		changed = function(val)
			len_offset[3] = 1 / val
		end,
	},
	{
		name = "f4",
		min = 1,
		max = 4,
		changed = function(val)
			len_offset[4] = 1 / val
		end,
	},
	{
		name = "open/close",
		min = 0,
		max = 1,
		changed = function(val)
			fb_sign = -1.0
			if val < 0.5 then
				fb_sign = 1.0
			end
		end,
	},
})
