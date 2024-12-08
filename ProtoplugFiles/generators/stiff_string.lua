--[[
TODO: gets unstable in high register!
]]

require("include/protoplug")

-- local Line = require("include/dsp/fdelay_line")
-- local Filter = require("include/dsp/cookbook_svf")

local scl =
	{ 73.751, 192.699, 311.647, 385.398, 504.346, 578.097, 697.045, 815.993, 889.744, 1008.692, 1082.443, 1201.391 }

polyGen.initTracks(16)

local decay = 1.0
local release = 1.0
local pedal = false
local pickup_p = 0.0
local play_p = 0.0
local nl_strength = 0.0
local high_damp = 0.0
local pluck_shape = 1.0
function polyGen.VTrack:init()
	self.hammer_f = 0
	self.hammer_t = 0
	self.f = 0.0
	self.vel = 0
	self.decay = 1.0
	self.release = 0.99
	self.n_points = 16
	self.px = {}
	self.py = {}
	self.vx = {}
	self.nvx = {}
	self.vy = {}

	for i = 1, 32 do
		self.px[i] = 0
		self.py[i] = 0
		self.vx[i] = 0
		self.nvx[i] = 0
		self.vy[i] = 0
	end
end

function processMidi(msg)
	if msg:isControl() then
		if msg:getControlNumber() == 64 then
			pedal = msg:getControlValue() ~= 0
		end
	end
end

-- spring force nonlinearity
local function nl(x)
	return x + nl_strength * x ^ 3
end

local function nl2(x)
	-- return -0.015 * math.min(x + 0.1, 0)
	return -0.002 * math.min(x, 0)
	-- return 0.02 * x * x
end

local function get_freq(note)
	local n = note - 60
	local l_i = n % 12

	local l_o = math.floor(n / 12)

	local cents = 0
	if l_i > 0 then
		cents = scl[l_i]
	end

	cents = cents + l_o * scl[#scl]
	print(cents)
	-- local f = 261.6256 * 2 ^ (n / 12)
	local f = 261.6256 * 2 ^ (cents / 1200)
	return (f / 44100)
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	for k = 0, smax do
		local s = 0
		if self.hammer_t < 1.0 then
			s = 0.5 - 0.5 * math.cos(2 * math.pi * (1.0 - self.hammer_t) ^ 2)
			-- s = math.sin(math.pi * self.hammer_t)
			s = s * self.vel

			-- s = s * (1.0 + 0.1 * (math.random() - 0.5))
		end
		self.hammer_t = self.hammer_t + self.hammer_f

		local damp = self.decay
		if self.finished and not pedal then
			-- self.decay = 0.99 * self.decay + 0.01 * self.release
			damp = self.release
		end

		for i = 2, self.n_points - 1 do
			self.nvx[i] = self.vx[i - 1] + self.vx[i + 1] - 2 * self.vx[i]
		end

		for i = 2, self.n_points - 1 do
			local force = 0
			force = force + nl(self.px[i - 1] - self.px[i])
			force = force + nl(self.px[i + 1] - self.px[i])
			-- force = force + nl2(self.px[i])

			local df = high_damp * self.nvx[i]
			self.vx[i] = damp * self.vx[i] + self.f * force + df

			if self.px[i] < -0.2 then
				self.vx[i] = self.vx[i] * 0.9995
			end
		end

		-- for i = 2, self.n_points - 1 do
		-- 	if self.px[i] < -0.5 then
		-- 		self.px[i] = -0.5
		-- 		self.vx[i] = 0
		-- 	end
		-- end

		local pickup_i = math.floor(pickup_p * self.n_points) + 1.0
		local play_i = math.floor(play_p * self.n_points) + 1.0

		self.vx[play_i] = self.vx[play_i] + self.f * s

		for i = 2, self.n_points - 1 do
			self.px[i] = self.px[i] + self.f * self.vx[i]
		end

		local out = self.vx[pickup_i]

		samples[0][k] = samples[0][k] + out
		samples[1][k] = samples[1][k] + out
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.finished = true
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.finished = false

	local d_range = 0.06
	local v = d_range * math.exp(-math.log(d_range) * (vel / 127) ^ 0.8)
	self.vel = v * 0.5
	-- self.vel = 0.2

	local f = get_freq(note)

	self.hammer_t = 0.0
	-- local h_off = 0.4 / (note / 127)
	-- self.hammer_f = h_off * f
	self.hammer_f = pluck_shape * (0.01 + 0.1 * (vel / 127)) * (f ^ 0.5)

	self.f = 30 * f

	self.n_points = 17
	if self.f > 0.5 then
		self.n_points = 9
		self.f = self.f * 0.5
	end

	-- self.decay = math.pow(decay, 0.001 / f)
	self.decay = decay
	self.release = release
end

params = plugin.manageParams({
	{
		name = "decay",
		min = 7,
		max = 15,
		default = 10,
		changed = function(val)
			decay = 1.0 - math.exp(-val)
			print(decay)
		end,
	},
	{
		name = "release",
		min = 4,
		max = 8,
		default = 6,
		changed = function(val)
			release = 1.0 - math.exp(-val)
			print(release)
		end,
	},
	{
		name = "playing position",
		min = 0,
		max = 0.5,
		default = 0.20,
		changed = function(val)
			play_p = val
		end,
	},
	{
		name = "pickup position",
		min = 0,
		max = 0.5,
		default = 0.10,
		changed = function(val)
			pickup_p = val
		end,
	},
	{
		name = "twang",
		min = 0,
		max = 1.0,
		default = 0.2,
		changed = function(val)
			nl_strength = val
		end,
	},
	{
		name = "high damp",
		min = 2,
		max = 5,
		default = 3.6,
		changed = function(val)
			high_damp = 10 ^ -val
		end,
	},
	{
		name = "pluck shape",
		min = -2,
		max = 2,
		default = 0.0,
		changed = function(val)
			pluck_shape = 2 ^ val
		end,
	},
})

-- params.resetToDefaults()
