require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

local sample_rate = 44100

polyGen.initTracks(32)

local pedal = false

local gain = 1
local wobble = 0.1

local x0 = 0.5
local y0 = 0.6

local bell_gain = 0.25
local bell_sustain = 0

local file_path = "samples/marimba_ir.wav"
local hammer_wav, hammer_len

plugin.addHandler("prepareToPlay", function()
	local reader = juce.AudioFormatReader(file_path)
	if reader == nil then
		error("Error: failed to open " .. file_path)
	end
	-- require stereo
	hammer_wav, hammer_len = reader:readToFloat(2)

	sample_rate = plugin.getSampleRate()
end)

local function pitch_to_hz(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return f
end

function polyGen.VTrack:init()
	self.pitch = 0
	self.vel = 0
	self.bright = 0
	self.active = false

	self.hammer_phase = 0
	self.hammer_f = 0
	self.hammer_pos = 0

	self.prev = 0

	self.freq = {}
	self.freq[1] = 440
	self.freq[2] = 440
	self.freq[3] = 440
	self.freq[4] = 440
	self.freq[5] = 440

	self.filters = {}
	self.filters[1] = Filter({ type = "bp", f = 440, Q = 0.7 })
	self.filters[2] = Filter({ type = "bp", f = 440, Q = 0.7 })
	self.filters[3] = Filter({ type = "bp", f = 440, Q = 0.7 })
	self.filters[4] = Filter({ type = "bp", f = 440, Q = 0.7 })
	self.filters[5] = Filter({ type = "bp", f = 440, Q = 0.7 })

	self.noise_filter = Filter({ type = "bp", f = 440, Q = 0.7 })
	self.noise_filter2 = Filter({ type = "lp", f = 440, Q = 0.7 })

	self.center = 0
end

function processMidi(msg)
	if msg:isControl() then
		if msg:getControlNumber() == 64 then
			pedal = msg:getControlValue() ~= 0

			if not pedal then
				for i, v in ipairs(polyGen.VTrack.tracks) do
					if not v.note_on then
						v:release()
					end
				end
			end
		end
	end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	if not self.active then
		return
	end
	for i = 0, smax do
		local hammer = 0
		-- if self.hammer_phase <= 1.0 then
		-- 	self.hammer_phase = self.hammer_phase + self.hammer_f

		-- 	local x = self.hammer_phase

		-- 	hammer = 45 * (x ^ 2) * ((1 - x) ^ 4)
		-- 	hammer = hammer * self.vel
		-- end
		-- local noise = math.random() - 0.5
		-- noise = hammer * noise
		-- local noise_high = self.noise_filter.process(noise)
		-- local noise_low = self.noise_filter2.process(noise)

		-- hammer = hammer + noise_low * 10 + noise_high
		-- -- hammer = hammer

		self.hammer_pos = self.hammer_pos + 1
		if self.hammer_pos < hammer_len then
			hammer = hammer_wav[0][self.hammer_pos]
		end

		hammer = hammer * self.vel

		local s1 = self.filters[1].process(hammer)
		local s2 = self.filters[2].process(hammer)
		local s3 = self.filters[3].process(hammer)
		local s4 = self.filters[4].process(hammer)
		local s5 = self.filters[5].process(hammer)

		local x = s1 + (0.02 * s4 + 0.025 * s2 + 0.008 * s3) * bell_gain
		local y = 0.2 * s5 * wobble

		x = x0 - x * gain
		y = y0 - y * gain

		-- pickup magnetic field
		local field = 1.0 / math.sqrt(y * y + x * x)
		field = field - self.center

		-- output voltage is derivative of magnetic field
		local diff = (field - self.prev)
		self.prev = field

		local out = 20 * diff / gain
		-- local out = hammer
		-- out = out + 0.2 * hammer

		samples[0][i] = samples[0][i] + out
		samples[1][i] = samples[1][i] + out
	end
end

local out_filter_l = Filter({ type = "ls", f = 280, Q = 0.7, gain = -10 })
local out_filter_r = Filter({ type = "ls", f = 280, Q = 0.7, gain = -10 })

function polyGen.processBlockGlobal(samples, smax)
	for i = 0, smax do
		local l = samples[0][i]
		local r = samples[1][i]

		l = out_filter_l.process(l)
		r = out_filter_r.process(r)

		samples[0][i] = l
		samples[1][i] = r
	end
end

function polyGen.VTrack:release()
	for i, v in ipairs(self.filters) do
		v.update({ Q = self.freq[i] * 0.15 })
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.note_on = false

	if not pedal then
		self:release()
	end
end

function polyGen.VTrack:updateCenter()
	self.center = 1 / math.sqrt(x0 * x0 + y0 * y0)
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.note_on = true
	self.active = true

	self.pitch = note

	local f = pitch_to_hz(self.pitch)
	local v = 2 ^ ((vel - 127) / 40)

	local decay = 1.0
	if note > 57 then
		local k = note - 57

		decay = 1 / (1 + (0.035 * k) ^ 4)
	end

	self.vel = 0.004 * v * (sample_rate / f)

	self.hammer_f = f / sample_rate
	self.hammer_f = math.min(self.hammer_f, 0.015)
	self.hammer_f = self.hammer_f * (0.4 + 0.7 * v)

	self.f = f / sample_rate

	self.freq[1] = f
	self.freq[2] = f * (7.10 + 0.3 * (math.random() - 0.5))
	self.freq[3] = f * (20.4 + 0.8 * (math.random() - 0.5))
	self.freq[4] = f * (0.62 + 0.15 * (math.random() - 0.5))
	self.freq[5] = f + 0.4 + 0.4 * math.random()

	self.filters[1].update({ f = self.freq[1], Q = self.freq[1] * 6.0 * decay })
	self.filters[2].update({ f = self.freq[2], Q = self.freq[2] * 0.2 * bell_sustain * decay })
	self.filters[3].update({ f = self.freq[3], Q = self.freq[3] * 0.1 * bell_sustain * decay })
	self.filters[4].update({ f = self.freq[4], Q = self.freq[4] * 0.3 * decay })
	self.filters[5].update({ f = self.freq[5], Q = self.freq[5] * 4.0 * decay })

	self.noise_filter.update({ f = self.freq[1], Q = self.freq[1] * 0.003 })
	self.noise_filter2.update({ f = self.freq[1] * 0.35, Q = 0.7 })

	self.hammer_phase = 0
	self.hammer_pos = 0

	self.prev = 0

	self.center = 1 / math.sqrt(x0 * x0 + y0 * y0)
end

params = plugin.manageParams({
	{
		name = "asymmetry",
		min = 0,
		max = 1,
		default = 0.4,
		changed = function(val)
			x0 = 0.6 * val
			for i, v in ipairs(polyGen.VTrack.tracks) do
				v:updateCenter()
			end
		end,
	},

	{
		name = "gain",
		min = -12,
		max = 12,
		default = 0,
		changed = function(val)
			gain = 10 ^ ((val - 6) / 20)
		end,
	},

	{
		name = "wobble",
		min = 0,
		max = 1,
		default = 0.2,
		changed = function(val)
			wobble = val * val
		end,
	},

	{
		name = "bell gain",
		min = 0,
		max = 1,
		default = 0.25,
		changed = function(val)
			bell_gain = 4 * val * val
		end,
	},

	{
		name = "bell sustain",
		min = 0,
		max = 1,
		default = 0.25,
		changed = function(val)
			bell_sustain = 1.0 + 12 * val * val
		end,
	},
})
params.resetToDefaults()
