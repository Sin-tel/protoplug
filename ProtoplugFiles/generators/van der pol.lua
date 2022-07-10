--[[
chaotic van der pol oscillators
--]]

require("include/protoplug")

local release = 100
local decayRate = 1 / release

local mu = 0.1

local a = 0

polyGen.initTracks(8)

function polyGen.VTrack:init()
	-- create per-track fields here
	self.releasePos = release

	self.phase = 0
	self.a = 0
	self.v = 0
	self.x = 0
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
		self.phase = self.phase + (self.noteFreq * math.pi)

		self.a = -((self.noteFreq * 2 * math.pi) ^ 2) * self.x
			+ mu * (1.0 - self.x * self.x) * self.v
			+ a * math.sin(self.phase) -- 0.0001*self.v
		self.v = self.v + self.a * dt
		self.x = self.x + self.v * dt
		if self.x > 10 then
			self.x = 10
		elseif self.x < -10 then
			self.x = -10
		end
		if self.v > 10 then
			self.v = 10
		elseif self.v < -10 then
			self.v = -10
		end
		-- math.sin is slow but once per sample is no tragedy
		local trackSample = self.x * amp * 0.1
		samples[0][i] = samples[0][i] + trackSample -- left
		samples[1][i] = samples[1][i] + trackSample -- right
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.releasePos = 0
end

function polyGen.VTrack:noteOn(note, vel, ev)
	-- start the sinewave at 0 for a clickless attack
	self.x = 1
	self.v = 0
end

params = plugin.manageParams({
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	{
		name = "Mu",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			mu = val
		end,
	},
	{
		name = "Drive",
		min = 0,
		max = 0.1,
		default = 0,
		changed = function(val)
			a = val
		end,
	},
})
