require("include/protoplug")
local cbFilter = require("include/dsp/cookbook_svf")

attack = 0.005
release = 0.005

polyGen.initTracks(4)

pedal = false

TWOPI = 2 * math.pi

local size = 25
local sparse = 0.2

local w_type = ffi.typeof("double[$][$]", size + 1, size + 1)
local w = ffi.new(w_type)
local w_in = ffi.new("double[?]", size + 1)
local w_out = ffi.new("double[?]", size + 1)
local w_bias = ffi.new("double[?]", size + 1)
local f_arr = ffi.new("double[?]", size + 1)

local function rnorm()
    return math.log(1 / math.random()) ^ 0.5 * math.cos(math.pi * math.random())
end

local freq = 6 * TWOPI / 44100

local gain_min = 0
local gain_pres = 1
local bias = 0

local pitch_offset = 0

for i = 1, size do
    w_in[i] = i % 2
    w_out[i] = (i + 1) % 2

    f_arr[i] = 1.0

    for j = 1, size do
        if math.random() < sparse then
            w[i][j] = math.random() - 0.5
        end
    end
end

local function softclip(x)
    local s = math.max(-3.0, math.min(3.0, x))
    return s * (27.0 + s * s) / (27.0 + 9.0 * s * s)
end

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

    self.fv = 0

    self.arr = ffi.new("double[?]", size + 1)
    self.a_new = ffi.new("double[?]", size + 1)

    self.high = cbFilter({ type = "hp", f = 10, gain = 0, Q = 0.7 })
end

local function curve(x)
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

            --self.f_ = self.f_ - (self.f_ - ch.f) * 0.002

            local fa = ch.f - self.f_
            self.fv = self.fv + freq * (fa - 0.4 * self.fv)
            self.fv = math.tanh(self.fv * 0.7 / self.f_) * (self.f_ / 0.7)
            self.f_ = self.f_ + freq * self.fv

            local gain = gain_min + gain_pres * self.pres_
            local freq = self.f_

            for i = 1, size do
                self.a_new[i] = bias * w_bias[i]
                for j = 1, size do
                    self.a_new[i] = self.a_new[i] + w[i][j] * self.arr[j] * gain
                end
            end

            local out = 0

            for i = 1, size do
                local y = softclip(self.a_new[i])
                local v = y - self.arr[i]

                self.arr[i] = self.arr[i] + math.min(freq * f_arr[i], 1.0) * v + 0.0001 * (math.random() - 0.5)
                out = out + w_out[i] * y
            end

            out = self.high.process(out * 0.1)

            samples[0][i] = samples[0][i] + out -- left
            samples[1][i] = samples[1][i] + out -- right
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
    local f = 2 ^ ((note + pitch_offset) / 12) * 261.625565
    return f / 44100
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
    {
        name = "Gain",
        min = 0,
        max = 8,
        default = 1,
        changed = function(val)
            gain_min = val
        end,
    },
    {
        name = "Gain press",
        min = 0,
        max = 4,
        default = 1,
        changed = function(val)
            gain_pres = val
        end,
    },
    {
        name = "bias",
        min = 0,
        max = 3,
        default = 0,
        changed = function(val)
            bias = val
        end,
    },
    {
        name = "pitch",
        min = -24,
        max = 24,
        default = 0,
        changed = function(val)
            pitch_offset = val
        end,
    },

    {
        name = "seed",
        min = 0,
        max = 200,
        default = 1,
        type = "int",
        changed = function(val)
            math.randomseed(val)
            for i = 1, size do
                w_bias[i] = math.random() - 0.5

                local ff = rnorm()

                ff = math.exp(ff * 3)
                --print(ff)
                f_arr[i] = ff
                for j = 1, size do
                    w[i][j] = 0
                    if math.random() < sparse then
                        local idx = i + j * size + val
                        w[i][j] = math.random() - 0.5
                    end
                end
            end
        end,
    },
})
