-- boilerplate example

require("include/protoplug")

polyGen.initTracks(8)

local pitchbend = 0
local pedal = false

local release = 0.99

local function getFreq(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return f / 44100
end

function polyGen.VTrack:init()
	self.f = 0
	self.phase = 0
	self.env = 0
	self.vel = 0
	self.pitch = 0
	self.finished = false
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
	end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	for k = 0, smax do
		self.phase = self.phase + (self.f * math.pi * 2)

		if self.finished and not pedal then
			self.env = self.env * release
		end

		if self.attack then
			self.env = self.env + 0.01
			if self.env >= 1.0 then
				self.attack = false
				self.env = 1.0
			end
		end

		local s = math.sin(self.phase)

		local sample = s * self.env * self.vel * 0.3
		samples[0][k] = samples[0][k] + sample
		samples[1][k] = samples[1][k] + sample
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.finished = true
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.finished = false
	self.pitch = note
	self.f = getFreq(self.pitch + pitchbend)

	local vel_range = 0.02
	local v = vel_range * math.exp(-math.log(vel_range) * (vel / 127) ^ 0.8)
	self.vel = v

	self.env = 0.0
	self.phase = 0

	self.attack = true
end

params = plugin.manageParams({
	{
		name = "release",
		min = 5,
		max = 12,
		default = 3,
		changed = function(val)
			release = 1.0 - math.exp(-val)
			print(release)
		end,
	},
})
