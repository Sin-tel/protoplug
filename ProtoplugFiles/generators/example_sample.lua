require("include/protoplug")

local path = "samples/marimba_ir.wav"
local wave, len

local original_sr = 44100
local sample_rate = 44100

local function pitch_to_f(note)
	local n = note - 60
	local f = 2 ^ (n / 12)
	return f * original_sr / sample_rate
end

plugin.addHandler("prepareToPlay", function()
	local reader = juce.AudioFormatReader(path)
	if reader == nil then
		error("Error: failed to open " .. path)
	end
	-- require stereo
	wave, len = reader:readToFloat(2)

	sample_rate = plugin.getSampleRate()
end)

polyGen.initTracks(8)

function polyGen.VTrack:noteOn(note, vel, ev)
	self.active = true
	self.position = 0
	self.f = pitch_to_f(note)
end

function polyGen.VTrack:noteOff(note, ev)
	self.active = false
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	if not self.active then
		return
	end
	for i = 0, smax do
		if self.position < len - 1 then
			self.position = self.position + self.f

			local p_int = math.floor(self.position)
			local alpha = self.position - p_int

			local sl0 = wave[0][p_int]
			local sl1 = wave[0][p_int + 1]
			local l = sl0 * (1 - alpha) + sl1 * alpha

			local sr0 = wave[1][p_int]
			local sr1 = wave[1][p_int + 1]
			local r = sr0 * (1 - alpha) + sr1 * alpha

			samples[0][i] = samples[0][i] + l
			samples[1][i] = samples[1][i] + r
		end
	end
end
