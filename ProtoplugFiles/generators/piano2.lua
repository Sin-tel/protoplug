--[[
4 strongly coupled strings
]]

require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
local Filter = require("include/dsp/cookbook_svf")

polyGen.initTracks(8)

local n_lines = 2

local pedal = false

local angle = 0

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
	self.hammer_f = 0.0
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
		self.hammer = self.hammer + self.hammer_f
		if self.hammer < 1.0 then
			s = (math.sin(math.pi * self.hammer)) * self.vel
			s = s * ((1.0 - hammer_noise) + hammer_noise * (math.random() - 0.5))
		end

		-- s = self.lp.process(s)
		-- s = self.hp.process(s)

		s = s * 2 - self.hammer * 0.00001

		local tot = 0

		for k = 1, n_lines do
			local d = self.delays[k].goBack(self.len_base * len_offset[k] - 1.0)
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

		s = s + tot
		if s < 0 then
			s = 0
		end
		if s > 1 then
			s = 1
		end
		s = s ^ 3

		-- if tot < rattle then
		-- 	tot = (tot + rattle) * f1 - rattle
		-- end

		-- local kc = math.cos(angle)
		-- local ks = math.sin(angle)

		local v1 = self.filter[1]
		local v2 = self.filter[2]
		-- local v3 = self.filter[3]
		-- local v4 = self.filter[4]
		self.delays[1].push(-v2 * f1 + s)
		self.delays[2].push(-v1 * f1)
		-- self.delays[3].push(-v4 * f1 + s)
		-- self.delays[4].push(-v3 * f1)

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
		max = 8,
		changed = function(val)
			local f_b = 1.001
			len_offset[2] = 1 / val
			len_offset[3] = f_b
			len_offset[4] = f_b / val
		end,
	},
})
