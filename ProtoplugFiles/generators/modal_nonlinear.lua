require("include/protoplug")

polyGen.initTracks(8)

local pitchbend = 0
local pedal = false

local release = 0.99

local MAX_HARMONICS = 16

local k = 0
local gap = 0.1

-- local harm = {
-- 	1.0,
-- 	1.002,
-- 	0.986,
-- 	2.3,
-- 	3.8,
-- 	5.2,
-- 	8.1,
-- 	9.6,
-- 	11.02,
-- 	14.4,
-- 	16.62,
-- 	16.97,
-- 	19.39,
-- 	21.46,
-- 	25.32,
-- 	29.67,
-- }

-- local amp = {
-- 	1.0,
-- 	0.1,
-- 	0.1,
-- 	0.2,
-- 	0.4,
-- 	0.2,
-- 	0.2,
-- 	0.1,
-- 	0.06,
-- 	0.04,
-- 	0.04,
-- 	0.04,
-- 	0.02,
-- 	0.02,
-- 	0.01,
-- 	0.01,
-- }

-- local amp = {
-- 	1.0,
-- 	0.1,
-- 	0.1,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- 	1.0,
-- }

local harm = {
	0.7502661200129709,
	0.991098812521631,
	1.0,
	1.0084379680945754,
	1.264405147782557,
	2.9377897065668375,
	5.69906035016523,
	8.459865299584669,
	12.733750022357675,
	12.756737016546634,
	12.906868148609378,
	13.666815346975286,
	14.31961805315113,
	14.371605314547889,
	14.52012795239093,
	14.737277785728299,
}

local amp = {
	0.24177247627077614,
	0.243971407126464,
	0.3360833677125924,
	0.22135526788750556,
	0.174414453262566,
	0.04220416242876087,
	0.024774774318927398,
	0.10229146817742264,
	0.06041333852357479,
	0.06521837911578016,
	0.03467144511774145,
	0.08220149730157818,
	0.20788052869161125,
	0.10081689739363742,
	0.34982543111422815,
	0.1475066709129454,
}

local decays = {
	583.1647390976965,
	124.56632292198026,
	3.336575056684033,
	29.059610983371616,
	1324.2797679276068,
	13.999385135595936,
	18.656809871471324,
	47.70517004424983,
	106.54519954354703,
	127.12975577128589,
	76.70060375639127,
	116.99631317935204,
	261.7233621012869,
	105.09676561816585,
	159.284626300533,
	324.62341217635714,
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
				hf = hf * (1.0 + 0.1 * ns)
			end

			hf = hf * self.vel * 0.1

			-- add excitation here
			local f_in = hf
			-- local f_in = 0

			-- open loop estimate
			local x_pred = 0
			for i = 1, self.n_harm do
				local v = self.v[i] + f_in
				local x = self.x[i]
				local x_next = self.g0[i] * x + self.g1[i] * v
				x_pred = x_pred + self.a[i] * x_next
			end

			-- solve for nonlinearity

			-- initial guess
			local x = 0.5 * (x_pred + self.x_prev)
			-- local force = 0

			-- local force = -k * (x + math.abs(x))
			local force = -k * x * math.abs(x)
			-- local force = -k * x * x * x

			-- local force = 0
			-- local x0 = x - gap
			-- if x0 > 0 then
			-- 	force = -k * x0
			-- end

			local total_input = f_in + force

			local out = 0
			for i = 1, self.n_harm do
				local x = self.x[i]
				local v = self.v[i]
				v = v + total_input

				local next_x = self.g0[i] * x + self.g1[i] * v
				local next_v = -self.g1[i] * x + self.g0[i] * v

				self.x[i] = next_x
				self.v[i] = next_v

				out = out + self.a[i] * x
			end

			self.x_prev = out

			out = out * self.gain

			samples[0][j] = samples[0][j] + out
			samples[1][j] = samples[1][j] + out
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
	self.G_total = 0

	for i = 1, MAX_HARMONICS do
		-- calculate coefficients

		-- g0, g1 frequency
		local f = self.f * harm[i]

		-- local decay = math.pow(0.99, 0.005 * pluck * i * i)

		local decay = (1 - 0.01 * decays[i] / 44100)

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
		self.a[i] = amp[i]

		-- total compliance
		self.G_total = self.G_total + self.a[i] * self.g1[i]
	end
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.dead = false
	self.finished = false
	self.pitch = note
	self.f = getFreq(self.pitch + pitchbend)
	self.env = 1.0

	self.h_phase = 0
	-- self.h_f = 2 * self.f
	self.h_f = 2 * self.f
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
})
