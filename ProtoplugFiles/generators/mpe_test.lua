require("include/protoplug")

local attack = 0.005
local release = 0.005

polyGen.initTracks(8)

local pedal = false

local TWOPI = 2 * math.pi

local function newChannel()
    local new = {}
    new.pressure = 0
    new.phase = 0
    new.pitch = 0
    new.pitchbend = 0
    new.vel = 0

    return new
end

local function getFreq(note)
    local f = 440 * 2 ^ ((note - 69) / 12)
    return f / 44100
end

local channels = {}

for i = 1, 16 do
    channels[i] = newChannel()
end

function polyGen.VTrack:init()
    self.channel = 0

    self.pitch = 0
    self.f = 0
    self.pres_ = 0
    self.fdbck = 0

    self.phase = 0
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
            --setPitch(chn)
        end
    elseif msg:isControl() then
        --print(msg:getControlNumber())

        if msg:getControlNumber() == 64 then
            pedal = msg:getControlValue() ~= 0
        end
    elseif msg:isPressure() then
        if ch > 1 then
            channels[ch].pressure = msg:getPressure() / 127
        end
    end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    local ch = channels[self.channel]

    if ch then
        for i = 0, smax do
            local a = attack
            if self.pres_ > ch.pressure then
                a = release
            end
            self.pres_ = self.pres_ - (self.pres_ - ch.pressure) * a

            local pt = ch.pitch + ch.pitchbend

            self.pitch = self.pitch - (self.pitch - pt) * 0.002

            self.f = getFreq(self.pitch) * TWOPI

            self.phase = self.phase + self.f

            local out = math.sin(self.phase + self.fdbck * self.pres_)
            self.fdbck = out

            local samp = out * self.pres_

            samples[0][i] = samples[0][i] + samp * 0.1 -- left
            samples[1][i] = samples[1][i] + samp * 0.1 -- right
        end
    end
end

function polyGen.VTrack:noteOff(note, ev)
    local i = ev:getChannel()
    local ch = channels[i]
    print(i, "off")
    ch.pressure = 0
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

    self.pitch = ch.pitch + ch.pitchbend
end

params = plugin.manageParams({
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
})
