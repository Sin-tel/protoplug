--[[
Microtonal simple FM synth

It uses the scale from Ben Johnston's piano suite.
this contains only overtones of the root.

The scale is automatically shifted so that the root is the lowest note currently playing. 
]]

require("include/protoplug")

local release = 1 * 44100
local decayRate = 1 - 1 / release

--local scale = {16/15,9/8,6/5,5/4,4/3,7/5,3/2,8/5,5/3,7/4,15/8}
--stylua: ignore
local scale = {17/16,9/8,19/16,5/4,21/16,11/8,3/2,13/8,27/16,7/4,15/8}
local notes = {}

local function getFreq(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return f / 44100
end

local function temper(note, root)
	local index = (note - root) % 12
	local oct = note - index
	if index > 0 then
		index = 12 * math.log(scale[index]) / math.log(2)
	end
	return oct + index
end

local function temperNotes()
	if #notes > 0 then
		local root = notes[1]

		for i = 1, polyGen.VTrack.numTracks do
			local vt = polyGen.VTrack.tracks[i]
			if vt.note >= 0 then
				vt.pitch = temper(vt.note, root)
				vt.f = getFreq(vt.pitch)
			end
		end
	end
end

polyGen.initTracks(16)

function polyGen.VTrack:init()
	-- create per-track fields here
	self.phase = 0
	self.f = 0
	self.pitch = 0
	self.fdbck = 0
	self.env = 0
	self.attack = 0
	self.vel = 0
end

function processMidi(msg)
	if msg:isPitchBend() then
		local p = msg:getPitchBendValue()
		p = (p - 8192) / 8192
		p = p * 2
		for i = 1, polyGen.VTrack.numTracks do
			local vt = polyGen.VTrack.tracks[i]
			vt.f = getFreq(vt.pitch + p)
		end
	end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	for i = 0, smax do
		self.attack = self.attack + 1 / 40
		if self.attack >= 1.0 then
			self.attack = 1.0
		end

		if self.env < 0.001 then
			break
		end
		self.env = self.env * decayRate

		self.phase = self.phase + (self.f * math.pi * 2)

		local m1 = math.sin(self.phase * 3.01) * 0.3 * self.env * self.vel
		local m2 = math.sin(self.phase * 6.98) * 0.08 * self.env * self.vel
		local fdb = self.fdbck * self.bright * self.vel

		local amp = self.env * self.attack * self.vel
		local trackSample = math.sin(self.phase + fdb + m1 + m2) * amp * 0.4
		self.fdbck = trackSample
		samples[0][i] = samples[0][i] + trackSample -- left
		samples[1][i] = samples[1][i] + trackSample -- right
	end
end

function polyGen.VTrack:noteOff(note, ev)
	local ind = nil
	for i, v in ipairs(notes) do
		if v == note then
			ind = i
		end
	end
	if ind then
		table.remove(notes, ind)
	end
	--temperNotes()
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.attack = 0
	self.env = 1
	--self.note = note
	table.insert(notes, note)
	table.sort(notes)
	--[[local s = ""
    for i,v in ipairs(notes) do
        s = s .. ", " .. v 
    end
    print(s)]]
	temperNotes()
	self.phase = 0
	self.vel = (vel / 127) ^ 2
	self.bright = math.min(2.0, 0.005 / self.f)
	--print(0.005/self.f)
end
