require("include/protoplug")

polyGen.initTracks(8)

local pitchbend = 0
local pedal = false

local release = 0.99

local MAX_HARMONICS = 8

local harm = {
	1.0,
	1.01,
	2.3,
	3.995,
	5.2,
	8.1,
	10.02,
	16.3,
}

local pluck = 0

local function getFreq(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return f / 44100
end

function polyGen.VTrack:init()
	self.f = 0
	self.pitch = 0
	self.finished = false
	self.dead = true
	self.n_harm = 0
	self.gain = 1 / MAX_HARMONICS
	self.env = 0

	-- state
	self.g0 = {}
	self.g1 = {}
	self.x = {}
	self.v = {}
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
	if not self.dead then
		if not self.finished then
			self:update_bank()
		end
		for k = 0, smax do
			if self.finished and not pedal then
				self.env = self.env * release
				if self.env < 0.0001 then
					self.dead = true
				end
			end

			local out = 0
			for i = 1, self.n_harm do
				local x = self.g0[i] * self.x[i] + self.g1[i] * self.v[i]
				local v = -self.g1[i] * self.x[i] + self.g0[i] * self.v[i]
				self.x[i] = x
				self.v[i] = v

				out = out + x
			end

			out = out * self.gain

			samples[0][k] = samples[0][k] + out
			samples[1][k] = samples[1][k] + out
		end
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.finished = true
	for i = 1, MAX_HARMONICS do
		self.g0[i] = self.g0[i] * release
		self.g1[i] = self.g1[i] * release
	end
end

function polyGen.VTrack:update_bank()
	for i = 1, MAX_HARMONICS do
		-- calculate coefficients
		local f = self.f * harm[i]

		local decay = math.pow(0.99, 0.01 * pluck * i)

		if f > 0.45 then
			break
		end

		self.n_harm = i
		local g = math.tan(math.pi * f)
		local gg = 2 / (1 + g * g)

		local g0 = gg - 1.0
		local g1 = g * gg

		self.g0[i] = g0 * decay
		self.g1[i] = g1 * decay
	end
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.dead = false
	self.finished = false
	self.pitch = note
	self.f = getFreq(self.pitch + pitchbend)
	self.env = 1.0

	local vel_range = 0.02
	local v = vel_range * math.exp(-math.log(vel_range) * (vel / 127) ^ 0.8)

	for i = 1, MAX_HARMONICS do
		-- initial impulse dirac
		local amp = v * (1 / i)
		self.x[i] = 0.0
		self.v[i] = amp
	end

	self:update_bank()
end

params = plugin.manageParams({
	{
		name = "release",
		min = 5,
		max = 12,
		default = 6,
		changed = function(val)
			release = 1.0 - math.exp(-val)
			print(release)
		end,
	},

	{
		name = "pluck",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			pluck = val
		end,
	},
})
