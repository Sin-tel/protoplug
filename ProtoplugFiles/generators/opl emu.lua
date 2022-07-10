--[[
name: sine organ
description: A simple organ-like sinewave VST/AU. 
author: osar.fr
--]]

require("include/protoplug")

local release = 40000
local decayRate = 1 / release

local ratio = 1

local mod = 0

local quality = false

local fdbck = 0

polyGen.initTracks(8)

function polyGen.VTrack:init()
	-- create per-track fields here
	self.releasePos = release

	self.phase = 0
	self.prev = 0
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	local amp = 1
	for i = 0, smax do
		if not self.noteIsOn then
			-- release is finished : idle track
			if self.releasePos >= release then
				break
			end
			-- release is under way
			amp = 1 - self.releasePos * decayRate
			self.releasePos = self.releasePos + 1
		end
		local dt = 1 --1/44100
		self.phase = self.phase + self.noteFreq

		self.phase = self.phase % 1

		local s2 = logsin(self.phase * ratio + fdbck * self.prev, (mod - 1) * 2048)

		local s = logsin(self.phase + s2, (amp - 1) * 2048)

		self.prev = s2

		-- math.sin is slow but once per sample is no tragedy
		local trackSample = s * 0.1
		samples[0][i] = samples[0][i] + trackSample -- left
		samples[1][i] = samples[1][i] + trackSample -- right
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.releasePos = 0
end

function polyGen.VTrack:noteOn(note, vel, ev)
	-- start the sinewave at 0 for a clickless attack
	self.phase = 0
end

function logsin(x, a)
	if quality then
		return math.sin(x * math.pi * 2) * math.pow(2, a / 256)
	else
		x = x % 1
		x = math.floor(x * 1024)
		local d = x < 512
		if not d then
			x = x - 512
		end
		local s = math.floor(256 * (math.log(math.sin((x + 0.5) * (math.pi / (256 * 2)))) / math.log(2)) + 0.5 + a)
		--print(x)

		local g = math.floor((math.pow(2, s / 256) - 1) * 1024 + 0.5) + 1024
		if d then
			return g / 1024
		else
			return -g / 1024
		end
	end

	--return math.sin(x*2*math.pi)
end

params = plugin.manageParams({
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	{
		name = "ratio",
		min = 1,
		max = 10,
		type = "int",
		default = 1,
		changed = function(val)
			ratio = val
		end,
	},
	{
		name = "mod",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			mod = val
		end,
	},
	{
		name = "feedback",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			fdbck = val
		end,
	},
	{
		name = "HQ",
		type = "list",
		values = { false, true },
		default = false,
		changed = function(val)
			quality = val
		end,
	},
})
