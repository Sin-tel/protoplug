-- boilerplate example

require("include/protoplug")

local model = require("generators/additive_bell")

polyGen.initTracks(16)

local pitchbend = 0
local pedal = false

local release = 0.99

local MAX_HARMONICS = model.N_PARTIALS

local phase = 0
local rand_amp = 0

local brightness = 0
local damp = 0
local decay_scale = 0

local function getFreq(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return f / 44100
end

function polyGen.VTrack:init()
	self.f = 0
	self.env = 0
	self.vel = 0
	self.pitch = 0
	self.finished = false
	self.dead = true
	self.n_harm = 0

	self.g0 = {}
	self.g1 = {}
	self.c = {}
	self.s = {}
	self.a = {}
	self.harm = {}
	self.a_base = {}
	self.a_random = {}
	self.ap = {}
	self.p = {}
	self.pc = {}
	self.ps = {}
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
		for k = 0, smax do
			if self.finished and not pedal then
				self.env = self.env * release
				if self.env < 0.001 then
					self.dead = true
				end
			end

			if self.attack then
				self.env = self.env + 0.01
				if self.env >= 1.0 then
					self.attack = false
					self.env = 1.0
				end
			end

			self.counter = self.counter + 1
			if self.counter >= 128 then
				self:update_bank()
				self.counter = 0
			end
			local ll = self.counter / 128

			local sr = 0
			local sl = 0
			for i = 1, self.n_harm do
				local a = (1 - ll) * self.ap[i] + ll * self.a[i]

				local t0 = self.g0[i] * self.c[i] - self.g1[i] * self.s[i]
				local t1 = self.g1[i] * self.c[i] + self.g0[i] * self.s[i]
				self.c[i] = t0
				self.s[i] = t1

				sl = sl + a * (self.pc[i] * t0 + self.ps[i] * t1)
				-- sr = sr + self.a[i] * (self.ps[i] * t0 - self.pc[i] * t1)
			end

			sl = sl * self.env * self.vel * 0.3
			sr = sl
			-- sr = sr * self.env * self.vel * 0.3
			samples[0][k] = samples[0][k] + sl
			samples[1][k] = samples[1][k] + sr
		end
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.finished = true
end

function polyGen.VTrack:update_bank()
	for i = 1, MAX_HARMONICS do
		-- local fi = (i - 1) * mult + 1
		-- fi = fi * math.sqrt(1 + inharm * i * i) / math.sqrt(1 + inharm)
		-- fi = fi + inharm * (i - 1) * (i - 1)

		local fi = self.harm[i]

		local f = self.f * fi

		-- local decay = math.pow(0.99, 0.01 * damp * i)
		local decay = (1 - (decay_scale * model.decays[i] * math.exp(damp * fi)) / 44100)

		decay = math.max(0, decay)
		-- local decay = (1 - decay_scale * model.decays[i] / 44100)

		if f > 0.45 then
			break
		end
		self.n_harm = i
		local g = math.tan(math.pi * f)
		local gg = 2 / (1 + g * g)

		self.g0[i] = gg - 1.0 -- cos(2*pi*f)
		self.g1[i] = g * gg -- sin(2*pi*f)

		self.g0[i] = self.g0[i] * decay
		self.g1[i] = self.g1[i] * decay

		self.pc[i] = math.cos(self.p[i])
		self.ps[i] = math.sin(self.p[i])
		self.ap[i] = self.a[i]

		local ka = math.min(1, f * rand_amp)
		self.a_random[i] = (1 - ka) * self.a_random[i] + ka * math.random() * 2
		self.a[i] = self.a_base[i] * self.a_random[i]
	end
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.counter = 0
	self.dead = false
	self.finished = false
	self.pitch = note
	self.f = getFreq(self.pitch + pitchbend)

	local vel_range = 0.02
	local v = vel_range * math.exp(-math.log(vel_range) * (vel / 127) ^ 0.8)
	self.vel = v

	self.env = 0.0

	self.attack = true

	for i = 1, MAX_HARMONICS do
		self.p[i] = model.phases[i] * 2 * math.pi
		self.c[i] = 0.0
		self.s[i] = 1.0
		-- self.a_base[i] = math.pow(i, -falloff)
		self.a_base[i] = model.amplitudes[i] * math.pow(i, -brightness)
		self.a[i] = self.a_base[i]
		self.ap[i] = self.a_base[i]
		self.a_random[i] = 1.0

		self.harm[i] = model.freqs[i]
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
		name = "brightness",
		min = -1,
		max = 1,
		default = 0,
		changed = function(val)
			brightness = val
		end,
	},

	{
		name = "decay scale",
		min = -2,
		max = 5,
		default = 0,
		changed = function(val)
			decay_scale = 2 ^ -val
		end,
	},

	{
		name = "damp",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			damp = val
		end,
	},
	{
		name = "noise",
		min = 0,
		max = 10,
		default = 0,
		changed = function(val)
			rand_amp = val
		end,
	},
})
