require("include/protoplug")

local attack = 0.005
local release = 0.005

polyGen.initTracks(1)

local pedal = false

local TWOPI = 2 * math.pi
local freq = 6 * TWOPI / 44100

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

    self.noise = 0
    self.noise2 = 0
    self.phase = 0

    self.fdbck = 0

    self.fv = 0

    self.t = 10
    self.vel = 0
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
            channels[ch].pressure = msg:getPressure() / 127
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

        --print(fw)

        for i = 0, smax do
            local a = attack
            if self.pres_ > ch.pressure then
                a = release
            end
            self.pres_ = self.pres_ - (self.pres_ - maxpres) * a

            --self.f_ = self.f_ - (self.f_ - ch.f)*0.002
            self.t = self.t + 1 / 44100

            local fa = ch.f - self.f_
            self.fv = self.fv + freq * (fa - 0.4 * self.fv)
            self.fv = math.tanh(self.fv * 0.7 / self.f_) * (self.f_ / 0.7)
            self.f_ = self.f_ + freq * self.fv

            local nse2 = math.random() - 0.5

            self.noise2 = self.noise2 - (self.noise2 - nse2) * 0.004

            --local p = math.exp(1-k*self.t)*k*self.t*self.vel
            local p = math.exp(-k * self.t) * (1 - math.exp(-10 * k * self.t)) * self.vel
            p = math.max(p, self.pres_)

            local addn = self.pres_ * self.pres_ * self.f_

            local nse = math.random() - 0.5

            self.noise = self.noise - (self.noise - nse) * 0.2

            self.phase = self.phase + (self.f_ * TWOPI) + nse * 0.4 * addn + self.noise2 * 0.1 * self.f_

            local out = math.sin(self.phase + self.fdbck * (p * 0.5 + 0.8) + self.noise * 0.1)

            --self.phase = self.phase + (self.f_*TWOPI)
            --local out = math.sin(self.phase +  self.fdbck*(self.pres_*0.5+0.8))

            self.fdbck = out

            local samp = out * p

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

    self.vel = vel / 127
    self.t = 0
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
        name = "Transient",
        min = 5,
        max = 50,
        default = 5,
        changed = function(val)
            k = val
        end,
    },
})
