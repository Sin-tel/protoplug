require("include/protoplug")

polyGen.initTracks(8)

local pitchbend = 0
local pedal = false

local release = 0.99

local MAX_HARMONICS = 64

local k = 0
local gap = 0.1

local inharm = 0.

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
	self.gain = 1 / 8
	self.env = 0
	self.vel = 0
	self.x_prev = 0

	self.h_phase = 0
	self.h_f = 0

	self.G_total = 0

	-- state
	self.g0 = {}
	self.g1 = {}
	self.x = {}
	self.v = {}
	self.a = {}
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
		for j = 0, smax do
			if self.finished and not pedal then
				self.env = self.env * release
				if self.env < 0.0001 then
					self.dead = true
				end
			end

			self.h_phase = self.h_phase + self.h_f
			local hf = 0
			if self.h_phase < 1.0 then
				local p = 2 * self.h_phase - 1
				hf = (1 - p * p) ^ 3

				local ns = math.random() - 0.5
				hf = hf * (1.0 + 0.0 * ns)
			end

			hf = hf * self.vel * 0.1

			-- add excitation here
			local f_in = hf
			-- local f_in = 0

			local x = self.x_prev

			-- local force = -k * (x + math.abs(x))
			-- local force = -k * x * math.abs(x)
			-- local force = -k * x * x * x
			-- local force = -k * (x - math.tanh(x))
			-- local force = -k * math.tanh(x)

			local force = 0
			local x0 = x - gap
			if x0 > 0 then
				force = -k * x0
				-- force = -k * x0 * x0
			end

			local total_input = f_in + force

			local x_sum = 0
			local v_sum = 0
			for i = 1, self.n_harm do
				local x = self.x[i]
				local v = self.v[i]
				v = v + total_input

				local next_x = self.g0[i] * x + self.g1[i] * v
				local next_v = -self.g1[i] * x + self.g0[i] * v

				self.x[i] = next_x
				self.v[i] = next_v

				x_sum = x_sum + self.a[i] * next_x
				v_sum = v_sum + self.a[i] * next_v
			end

			self.x_prev = x_sum

			local out = v_sum * self.gain

			samples[0][j] = samples[0][j] + out
			samples[1][j] = samples[1][j] + out
		end
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.finished = true
	for i = 1, self.n_harm do
		self.g0[i] = self.g0[i] * release
		self.g1[i] = self.g1[i] * release
	end
end

function polyGen.VTrack:update_bank()
	self.G_total = 0

	for i = 1, MAX_HARMONICS do
		-- calculate coefficients

		-- g0, g1 frequency

		local fi = math.sqrt(1 + inharm * i * i) / math.sqrt(1 + inharm)

		-- local f = self.f * harm[i]
		local f = self.f * i * fi

		-- local decay = math.pow(0.99, 0.005 * pluck * i * i)
		local decay = math.pow(0.99, 0.005 * pluck * i)

		-- local decay = (1 - 0.01 * decays[i] / 44100)

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

		-- amplitude
		-- self.a[i] = amp[i]
		self.a[i] = 1.0
	end
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.dead = false
	self.finished = false
	self.pitch = note
	self.f = getFreq(self.pitch + pitchbend)
	self.env = 1.0

	self.h_phase = 0
	self.h_f = 1.2 * self.f
	-- self.h_f = 100 / 44100

	local vel_range = 0.02
	local v = vel_range * math.exp(-math.log(vel_range) * (vel / 127) ^ 0.8)

	self.vel = v

	for i = 1, MAX_HARMONICS do
		-- initial impulse
		-- local a = v * (1 / i)
		self.x[i] = 0.0
		self.v[i] = 0.0
		--self.v[i] = v
		-- self.v[i] = v * (1 / i)

		-- if i == 1 then
		-- 	self.v[i] = v
		-- else
		-- 	self.v[i] = 0
		-- end
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
			pluck = val * val
		end,
	},

	{
		name = "k",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			k = 0.1 * val * val
		end,
	},

	{
		name = "gap",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			gap = val * val
		end,
	},

	{
		name = "inharmonicity",
		min = 0,
		max = 2,
		default = 0,
		changed = function(val)
			inharm = 0.01 * val * val
		end,
	},
})
