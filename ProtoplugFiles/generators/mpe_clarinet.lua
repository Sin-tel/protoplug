--[[
model of a clarinet that actually sounds like a flute
]]

require("include/protoplug")

local Line = require("include/dsp/delay_line")
local cbFilter = require("include/dsp/cookbook filters")

local attack = 0.005
local release = 0.005
local kappa = 0
local split = 0.8
local mod = 0

local tun_m = 1
local tun_o = 0

polyGen.initTracks(8)

pedal = false

TWOPI = 2 * math.pi

local freq = 35 * TWOPI / 44100

function newChannel()
	new = {}

	new.pressure = 0

	new.phase = 0
	new.f = 0
	new.pitch = 0
	new.pitchbend = 0
	new.vel = 0
	new.slide = 0

	return new
end

channels = {}

for i = 1, 16 do
	channels[i] = newChannel()
end

function setPitch(ch)
	ch.f = getFreq(ch.pitch + ch.pitchbend)
end

function polyGen.VTrack:init()
	self.channel = 0

	self.f_ = 0
	self.pres_ = 0
	self.phase = 0

	self.fv = 0

	self.delayL = {}
	self.delayL[1] = Line(512)
	self.delayL[2] = Line(512)

	self.delayR = {}
	self.delayR[1] = Line(512)
	self.delayR[2] = Line(512)

	self.lp = cbFilter({
		-- initialize filters with current param values
		type = "lp",
		f = 4000,
		gain = 0,
		Q = 0.7,
	})

	self.dcblock = cbFilter({
		-- initialize filters with current param values
		type = "hp",
		f = 50,
		gain = 0,
		Q = 0.7,
	})
	self.noisefilter = cbFilter({
		-- initialize filters with current param values
		type = "bp",
		f = 500,
		gain = 0,
		Q = 1.0,
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

		if msg:getControlNumber() == 74 then
			local chn = channels[ch]
			chn.slide = (msg:getControlValue() - 64) / 64
		end
	elseif msg:isPressure() then
		if ch > 1 then
			local pr = msg:getPressure() / 127
			-- pr = 1 - (1-pr)*(1-pr)
			channels[ch].pressure = pr
		end
	end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	local ch = channels[self.channel]

	if ch then
		local maxpres = 0

		for i = 1, 16 do
			local p = channels[i].pressure
			if p > maxpres then
				maxpres = p
			end
		end

		for i = 0, smax do
			local a = attack
			if self.pres_ > ch.pressure then
				a = release
			end
			self.pres_ = self.pres_ - (self.pres_ - ch.pressure) * a

			--self.f_ = self.f_ - (self.f_ - ch.f)*0.002

			local fa = ch.f - self.f_
			self.fv = self.fv + freq * (fa - 0.4 * self.fv)
			self.fv = math.tanh(self.fv * 0.7 / self.f_) * (self.f_ / 0.7)
			self.f_ = self.f_ + freq * self.fv

			self.phase = self.phase + freq
			--self.phase = self.phase + (0.1*self.f_ * TWOPI)

			local nse = math.random() - 0.5
			nse = self.noisefilter.process(nse)

			local len = 1 / (4 * self.f_ * tun_m) + tun_o

			local spp = split * (1.0 - mod * self.pres_)

			local l1 = spp * len
			local l2 = (1 - spp) * len

			--[[local spl2 = math.min(10, len*0.5)
            
            local l1 = len - spl2
            local l2 = spl2]]

			local boreOut = self.delayL[1].goBack(l1)

			--boreOut = self.lp.process(boreOut)

			local pressure = (1.0 + 0.3 * nse + ch.slide * 0.5 * math.sin(self.phase)) * self.pres_

			local presdiff = boreOut - pressure
			local refl = -1.6 * presdiff + 0.2
			refl = math.tanh(refl)

			local bell = -0.95 * self.delayR[2].goBack(l2)

			local scr = self.delayR[1].goBack(l1)
			local scl = self.delayL[2].goBack(l2)

			local w = kappa * (scr - scl)

			self.delayR[1].push(pressure + presdiff * refl)
			--self.delayR[1].push(pressure + boreOut)
			self.delayL[1].push(scl + w)

			self.delayR[2].push(scr + w)
			self.delayL[2].push(bell)

			local out = self.dcblock.process(bell)

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

	--[[ for j =1,16 do
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
    end]]
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

function getFreq(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return f / 44100
end

params = plugin.manageParams({
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	{
		name = "Attack",
		min = 4,
		max = 10,
		default = 4.5,
		changed = function(val)
			attack = math.exp(-val)
		end,
	},
	{
		name = "Release",
		min = 4,
		max = 12,
		default = 7,
		changed = function(val)
			release = math.exp(-val)
		end,
	},
	{
		name = "Kappa",
		min = -1,
		max = 1,
		default = 0.3,
		changed = function(val)
			kappa = val
		end,
	},
	{
		name = "Split",
		min = 0,
		max = 1,
		default = 0.11,
		changed = function(val)
			split = val
		end,
	},
	{
		name = "Split mod",
		min = 0,
		max = 1,
		default = 0.3,
		changed = function(val)
			mod = val
		end,
	},
	{
		name = "Tune master",
		min = -0.5,
		max = 0.5,
		default = 0.0625,
		changed = function(val)
			tun_m = math.exp(val)
		end,
	},
	{
		name = "Tune offset",
		min = -10,
		max = 10,
		default = -2.61,
		changed = function(val)
			tun_o = val
		end,
	},
})

params.resetToDefaults()
