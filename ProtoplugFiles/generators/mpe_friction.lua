require("include/protoplug")

attack = 0.005
release = 0.005

polyGen.initTracks(8)

pedal = false

TWOPI = 2 * math.pi

local freq = 6 * TWOPI / 44100

function newChannel()
    new = {}

    new.pressure = 0

    new.phase = 0
    new.f = 0
    new.pitch = 0
    new.pitchbend = 0

    new.vel = 0

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

    self.noise = 0
    self.noise2 = 0
    self.phase = 0

    self.fdbck = 0

    self.fv = 0

    self.x1 = 0.0
    self.v1 = 0.0

    self.x2 = 0.0
    self.v2 = 0.0

    self.x3 = 0.0
    self.v3 = 0.0
end

local function curve(x)
    --local g = 1-x
    --return 1-g*g
    return x
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
            channels[ch].pressure = curve(msg:getPressure() / 127)
        end
    end
end

function sign(number)
    return number > 0 and 1 or (number == 0 and 0 or -1)
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    local ch = channels[self.channel]

    if ch then
        local dt = 1 / 44100

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

            local nse = math.random() - 0.5

            self.noise = nse

            local force = 0.002 * self.noise * self.pres_

            local delta = self.v1
                + 0.8 * self.v2
                + 0.8 * self.v3
                - 0.01 * math.min(1.1, self.pres_ * 0.2 + 0.98)
                + force

            local sgn = sign(delta)
            local friction = math.abs(delta)

            if friction > 0.01 then
                friction = 0.005
            end

            friction = 2 * friction * self.f_ * self.pres_ ^ 2 + 0.01 * force

            self.v1 = self.v1
                - sgn * friction
                - 0.0005 * self.v1
                - ((2 * math.pi * self.f_) ^ 2) * self.x1 * (1.0 + 1.0 * self.x1 * self.x1)
            self.x1 = self.x1 + self.v1

            self.v2 = self.v2
                - sgn * friction
                - 0.0005 * self.v2
                - ((4.78 * 2 * math.pi * self.f_) ^ 2) * self.x2 * (1.0 + 1.0 * self.x2 * self.x2)
            self.x2 = self.x2 + self.v2

            self.v3 = self.v3
                - sgn * friction
                - 0.0005 * self.v3
                - ((6.38 * 2 * math.pi * self.f_) ^ 2) * self.x3 * (1.0 + 1.0 * self.x3 * self.x3)
            self.x3 = self.x3 + self.v3

            --self.x = self.x * math.min(1.0, 1.0 / math.abs(self.x))

            local out = self.x1 + 0.9 * self.x2 + 0.9 * self.x3

            local samp = out

            samples[0][i] = samples[0][i] + samp -- left
            samples[1][i] = samples[1][i] + samp -- right
        end
    end
end

function polyGen.VTrack:noteOff(note, ev)
    local i = ev:getChannel()
    local ch = channels[i]

    ch.pressure = 0
end

function polyGen.VTrack:noteOn(note, vel, ev)
    local i = ev:getChannel()

    local vtrack = self

    local assignNew = true
    for j = 1, polyGen.VTrack.numTracks do
        local vt = polyGen.VTrack.tracks[j]
        if vt.channel == i then
            assignNew = false
            vtrack = vt
        end
    end

    --if assignNew then
    vtrack.channel = i
    --end

    local ch = channels[i]

    ch.pitch = note

    ch.pressure = 0

    setPitch(ch)
    vtrack.f_ = ch.f
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
