require("include/protoplug")

local Filter = require("include/dsp/cookbook_svf")
local coefs = require("effects/lattice_coefs")
local c_len = #coefs["a"]

local attack = 0.005
local release = 0.005

polyGen.initTracks(1)

local pedal = false

local TWOPI = 2 * math.pi
local freq = 7 * TWOPI / 44100

local tenseness = 0

local tract_phones = { "a", "e", "i", "o", "u" }

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

    self.f_ = 1
    self.pres_ = 0
    self.g_prev = 0

    self.noise = 0
    self.noise2 = 0
    self.phase = 0

    self.fdbck = 0

    self.fv = 0

    self.t = 10
    self.vel = 0

    self.noise_filter = Filter({ type = "bp", f = 800, Q = 0.4 })

    self.lf = {}
    self.lg = {}
    self.coefs = {}
    self.coefs_target = {}
    for i = 0, c_len do
        self.lf[i] = 0
        self.lg[i] = 0
        self.coefs[i] = coefs.a[i]
        self.coefs_target[i] = coefs.a[i]
    end
end

function processMidi(msg)
    -- print(msg:debug())
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
            if msg:getPressure() <= 127 then -- god knows why this is necessary
                channels[ch].pressure = msg:getPressure() / 127
            end
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

            self.t = self.t + 1 / 44100

            -- frequency spring
            local fa = ch.f - self.f_
            self.fv = self.fv + freq * (fa - 0.6 * self.fv)
            local s_a = 0.9
            self.fv = math.tanh(self.fv * s_a / self.f_) * (self.f_ / s_a)
            self.f_ = self.f_ + freq * self.fv

            -- phase update
            local nse2 = math.random() - 0.5
            self.noise2 = self.noise2 - (self.noise2 - nse2) * 0.01
            self.phase = self.phase + self.f_ * (1 + 0.05 * self.noise2)
            self.phase = self.phase % 1

            -- glottis sim
            local p = self.pres_

            local tense = p * tenseness

            local s = 0.888 + 0.1 * tense
            local t_p = 0.7 - 0.2 * tense
            local t_mid = s * t_p
            local u = s * s * s * (1 - s)
            local b = s * s * (4 * s - 3) / (3 * u * t_p)
            local t_end = t_mid + 1 / b

            local g = 0
            if self.phase < t_mid then
                -- open phase
                local x = self.phase / t_p
                g = x * x * x * (1 - x)
            elseif self.phase < t_end then
                -- return closing
                local x = 1 - b * (self.phase - t_mid)
                g = u * x * x * x
            end

            local dg = (g - self.g_prev) / self.f_
            self.g_prev = g

            local asp = math.random() - 0.5
            asp = asp * (dg + 0.5 * (1 - tense))
            asp = self.noise_filter.process(asp)

            local pre_vt = (dg + 0.2 * asp) * p

            -- vocal tract lattice filter
            self.lf[c_len] = pre_vt
            for m = c_len, 1, -1 do
                local k = self.coefs[m]
                self.coefs[m] = self.coefs[m] - (self.coefs[m] - self.coefs_target[m]) * 0.0001
                self.lf[m - 1] = self.lf[m] - k * self.lg[m - 1]
                self.lg[m] = k * self.lf[m - 1] + self.lg[m - 1]
            end
            local out = self.lf[0]
            self.lg[0] = out

            samples[0][i] = samples[0][i] + out * 0.1 -- left
            samples[1][i] = samples[1][i] + out * 0.1 -- right
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
        -- self.f_ = channels[maxi].f
        print(self.channel, "active")
    end
end

function polyGen.VTrack:setCoefs()
    local k_i = math.random(#tract_phones)
    local k_target = tract_phones[k_i]
    local k_start = k_target
    -- if math.random() < 0.2 then
    --     k_start = "n"
    -- end

    if math.random() < 0.2 then
        k_start = "i"
    end
    for i = 1, c_len do
        self.coefs_target[i] = coefs[k_target][i]
        self.coefs[i] = 0.5 * (coefs[k_start][i] + coefs[k_target][i])
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
    local maxpres = 0

    for j = 1, 16 do
        local p = channels[j].pressure
        if p > maxpres then
            maxpres = p
        end
    end

    if maxpres < 0.01 then
        self:setCoefs()
        self.f_ = ch.f
    end

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
        name = "Max Tense",
        min = 0,
        max = 1,
        default = 0.5,
        changed = function(val)
            tenseness = val
        end,
    },
})
