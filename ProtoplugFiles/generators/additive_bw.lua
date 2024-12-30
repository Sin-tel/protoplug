-- "bandwidth-enhanced additive model" as in loris
-- https://www.cerlsoundgroup.org/Loris/

require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

polyGen.initTracks(8)

local pitchbend = 0
local pedal = false

local release = 0.99

local MAX_HARMONICS = 16

local falloff = 1.0

local inharm = 0

local mult = 0
local offset = 0
local pluck = 0

local kappa = 0

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

	self.k1 = {}
	self.k2 = {}

	self.noise_filter = {}
	self.noise_gain = {}
	for i = 1, MAX_HARMONICS do
		self.noise_filter[i] = Filter({ type = "lp", f = 80.0, gain = 0, Q = 0.7 })
		self.noise_gain[i] = 1.0

		self.k1[i] = 1
		self.k2[i] = 0
	end
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
			-- local ll = self.counter / 128

			local sr
			local sl = 0
			for i = 1, self.n_harm do
				-- local a = (1 - ll) * self.ap[i] + ll * self.a[i]
				local a = self.a[i]

				-- should really be gaussian
				local zeta = (math.random() - 0.5) * self.noise_gain[i]
				zeta = self.noise_filter[i].process(zeta)

				local t0 = self.g0[i] * self.c[i] - self.g1[i] * self.s[i]
				local t1 = self.g1[i] * self.c[i] + self.g0[i] * self.s[i]
				self.c[i] = t0
				self.s[i] = t1

				sl = sl + a * (self.k1[i] + self.k2[i] * zeta) * t0
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
		local fi = (i - 1) * mult + 1

		local ih = 0.01 * inharm
		fi = fi * math.sqrt(1 + ih * i * i) / math.sqrt(1 + ih)

		local f = self.f * fi

		local decay = math.pow(0.99, 0.01 * pluck * i)

		f = f + offset / 44100

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

		local f_filter = f * 0.01
		self.noise_gain[i] = 0.02 / f_filter
		self.noise_filter[i].update({ f = 44100 * f_filter })

		local k = 0.1 * kappa * i

		k = math.min(math.max(k, 0.), 1.)

		self.k1[i] = math.sqrt(1.0 - k)
		self.k2[i] = math.sqrt(2.0 * k)
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
		-- self.p[i] = phase * math.random() * 2 * math.pi
		self.c[i] = 0.0
		self.s[i] = 1.0
		self.a[i] = math.pow(i, -falloff)
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
		name = "inharmonicity",
		min = 0,
		max = 2,
		default = 0,
		changed = function(val)
			-- inharm = 0.01 * val * val
			inharm = val
		end,
	},
	{
		name = "frequency shift",
		min = -50,
		max = 50,
		default = 0,
		changed = function(val)
			offset = val
		end,
	},
	{
		name = "multiplier",
		min = 0,
		max = 10,
		default = 1,
		changed = function(val)
			mult = val
		end,
	},

	{
		name = "brightness",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			falloff = 1 + 2 * (1 - val)
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

	{
		name = "kappa",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			kappa = val
		end,
	},
})
