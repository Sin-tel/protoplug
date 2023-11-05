require("include/protoplug")

local Line = require("include/dsp/delay_line")
local cbFilter = require("include/dsp/cookbook filters")

local attack = 0.005
local release = 0.005
local boreGain = 0
local harmonic = 2
local jetGain = 1

--local xfade = 0

polyGen.initTracks(8)

local pedal = false

local function newChannel()
	local new = {}

	new.pressure = 0

	new.phase = 0
	new.f = 0
	new.pitch = 0
	new.pitchbend = 0
	new.vel = 0

	return new
end

local channels = {}

for i = 1, 16 do
	channels[i] = newChannel()
end

local function getFreq(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return f / 44100
end

local function setPitch(ch)
	ch.f = getFreq(ch.pitch + ch.pitchbend)
end

function polyGen.VTrack:init()
	self.channel = 0

	self.f_ = 0
	self.pres_ = 0
	self.phase = 0

	self.fv = 0

	self.delayLine = Line(1024)
	self.jetDelay = Line(1024)

	self.ap = Line(100)

	self.lp = cbFilter({
		-- initialize filters with current param values
		type = "lp",
		f = 3000,
		gain = 0,
		Q = 0.7,
	})

	self.noisefilter = cbFilter({
		-- initialize filters with current param values
		type = "bp",
		f = 2000,
		gain = 0,
		Q = 1.0,
	})

	self.dcblock = cbFilter({
		-- initialize filters with current param values
		type = "hp",
		f = 200,
		gain = 0,
		Q = 0.7,
	})
end

function processMidi(msg)
	--print(msg:debug())
	local ch = msg:getChannel()
	if msg:isPitchBend() then
		local p = msg:getPitchBendValue()
		if ch ~= 1 then
			p = (p - 8192) / 8192
			local pitchbend = p * 48

			local chn = channels[ch]
			chn.pitchbend = pitchbend
			setPitch(chn)
		end
	elseif msg:isControl() then
		--print(msg:getControlNumber())

		if msg:getControlNumber() == 64 then
			pedal = msg:getControlValue() ~= 0
		end
	elseif msg:isPressure() then
		if ch > 1 then
			local pr = msg:getPressure() / 127
			pr = 1 - (1 - pr) * (1 - pr)
			--pr = pr*pr
			channels[ch].pressure = pr
		end
	end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	local ch = channels[self.channel]

	if ch then
		--[[local maxpres = 0
        for i =1,16 do
            local p = channels[i].pressure
            if p > maxpres then
                maxpres = p
            end
        end]]

		for i = 0, smax do
			local a = attack
			if self.pres_ > ch.pressure then
				a = release
			end
			self.pres_ = self.pres_ - (self.pres_ - ch.pressure) * a

			self.f_ = self.f_ - (self.f_ - ch.f) * 0.001

			self.pres_ = self.pres_ - math.abs(self.f_ - ch.f) * 0.3

			local nse = math.random() - 0.5

			nse = nse * self.pres_
			nse = self.noisefilter.process(nse)

			local boreOut = 0.95 * self.delayLine.goBack(1 / self.f_ - 10)

			boreOut = self.lp.process(boreOut)

			local pressure = (1.0 + 0.04 * nse) * self.pres_

			local jet = pressure + boreOut

			--jet = math.max(-1,math.min(1,jet))
			--jet = jet - jet*jet*jet

			jet = math.tanh(jet)
			jet = jet - 2 * jet * jet * jet

			local r = self.jetDelay.goBack(1 / (self.f_ * harmonic))

			local boreIn = jetGain * r + boreGain * boreOut

			--alpass
			local kap = 0.5
			local d = self.ap.goBack_int(10)
			local v = boreIn - kap * d
			boreIn = kap * v + d

			self.ap.push(v)
			---

			self.jetDelay.push(jet)
			self.delayLine.push(boreIn)

			local out = self.dcblock.process(boreOut)

			local samp = out

			samples[0][i] = samples[0][i] + samp * 0.5 -- left
			samples[1][i] = samples[1][i] + samp * 0.5 -- right
		end
	end
end

function polyGen.VTrack:noteOff(note, ev)
	local i = ev:getChannel()
	local ch = channels[i]
	print(i, "off")
	ch.pressure = 0

	local maxpres = 0
	local maxi = 0

	for j = 1, 16 do
		local p = channels[j].pressure
		if p > maxpres then
			maxpres = p
			maxi = j
		end
	end

	if maxpres > 0.01 then
		self.channel = maxi
		self.f_ = channels[maxi].f
		print(self.channel, "active")
	end
end

function polyGen.VTrack:noteOn(note, vel, ev)
	local i = ev:getChannel()
	--activech = i
	print(i, "on")

	local assignNew = true
	for j = 1, polyGen.VTrack.numTracks do
		local vt = polyGen.VTrack.tracks[j]
		if vt.channel == i then
			assignNew = false
		end
	end

	if assignNew then
		self.channel = i
	end

	local ch = channels[i]

	ch.pitch = note

	ch.pressure = 0

	setPitch(ch)
	self.f_ = ch.f

	print(1 / self.f_)

	-- self.pres_ = 0
end

params = plugin.manageParams({
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	{
		name = "Attack",
		min = 4,
		max = 10,
		default = 5,
		changed = function(val)
			attack = math.exp(-val)
		end,
	},
	{
		name = "Release",
		min = 4,
		max = 12,
		default = 5,
		changed = function(val)
			release = math.exp(-val)
		end,
	},
	{
		name = "Bore gain",
		min = 0,
		max = 0.5,
		default = 0,
		changed = function(val)
			boreGain = val
		end,
	},
	{
		name = "Jet  gain",
		min = 0,
		max = 1.0,
		default = 0,
		changed = function(val)
			jetGain = val
		end,
	},
	{
		name = "Harmonic",
		min = 1,
		max = 10,
		default = 1,
		changed = function(val)
			harmonic = val
		end,
	},
})
