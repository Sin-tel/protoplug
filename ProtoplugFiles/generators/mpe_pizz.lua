require("include/protoplug")

local decay = 0.005
local release = 0.005

polyGen.initTracks(15)

local pedal = false

local TWOPI = 2 * math.pi

local freq = 6 * TWOPI / 44100

local VEL_MIN = 0.02
local LOG_RANGE = -math.log(VEL_MIN)

local function velocity_curve(x)
    local v = x ^ 0.8
    local out = VEL_MIN * math.exp(LOG_RANGE * v)
    return out
end

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
    self.envelope = 0

    self.noise = 0
    self.noise2 = 0
    self.phase = 0

    self.fdbck = 0

    self.fv = 0
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
        for i = 0, smax do
            if pedal then
                self.envelope = self.envelope * (1 - decay)
            else
                self.envelope = self.envelope * (1 - self.env_decay)
            end

            --self.f_ = self.f_ - (self.f_ - ch.f)*0.002

            local fa = ch.f - self.f_
            self.fv = self.fv + freq * (fa - 0.4 * self.fv)
            self.fv = math.tanh(self.fv * 0.7 / self.f_) * (self.f_ / 0.7)
            self.f_ = self.f_ + freq * self.fv

            local nse2 = math.random() - 0.5
            self.noise2 = self.noise2 - (self.noise2 - nse2) * 0.004

            local nse = math.random() - 0.5
            self.noise = self.noise - (self.noise - nse) * 0.2

            local addn = self.envelope * self.envelope * self.f_

            self.phase = self.phase + (self.f_ * TWOPI) + nse * 0.4 * addn + self.noise2 * 0.1 * self.f_
            local out = math.sin(self.phase + self.fdbck * self.envelope)

            self.fdbck = out
            local samp = out * self.envelope

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
    self.env_decay = release
end

function polyGen.VTrack:noteOn(note, vel, ev)
    local i = ev:getChannel()
    print(i, "on")

    self.channel = i
    self.phase = 0
    self.fdbck = 0

    local ch = channels[i]

    ch.pitch = note

    ch.pressure = 0

    setPitch(ch)
    self.env_decay = decay
    self.f_ = ch.f

    local v = velocity_curve(vel / 127)

    local ktrack = 1 - note / 127

    self.envelope = v * ktrack
end

params = plugin.manageParams({
    -- automatable VST/AU parameters
    -- note the new 1.3 way of declaring them
    {
        name = "decay",
        min = 4,
        max = 12,
        default = 5,
        changed = function(val)
            decay = math.exp(-val)
        end,
    },

    {
        name = "release",
        min = 4,
        max = 12,
        default = 5,
        changed = function(val)
            release = math.exp(-val)
        end,
    },
})
