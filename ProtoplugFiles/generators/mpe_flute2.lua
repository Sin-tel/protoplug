require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
local Filter = require("include/dsp/cookbook_svf")

local attack = 0.005
local release = 0.005

local pedal = false

local active_channel = 1

local freq = 0
local len = 100
local pres = 0

local prev_s = 0

local harmonic = 2

local attack_env = 0.0

local transition = false
local t_time = 0.0
local t_time_total = 0.006
local prev_len = 0
local prev_f = 0

local bore_delay = Line(4000)

local base_feedback = 0.2
local pres_feedback = 0.7

local refl = 0.75

local gate = 0.0

local r_filter = Filter({
    type = "bp",
    f = 3000,
    gain = 0,
    Q = 1.5,
})

local f_hp = Filter({
    type = "hp",
    f = 10,
    gain = 0,
    Q = 0.7,
})

local f_lp = Filter({
    type = "lp",
    f = 5000,
    gain = 0,
    Q = 0.7,
})

local f_vibrato = Filter({
    type = "bp",
    f = 5,
    gain = 0,
    Q = 1.2,
})

local function newChannel()
    local new = {}

    new.pressure = 0
    new.f = 0
    new.f_base = 0
    new.pitch = 0
    new.pitchbend = 0
    new.vel = 0

    return new
end

local channels = {}

local queue = {}

for i = 1, 16 do
    channels[i] = newChannel()
end

local VEL_MIN = 0.02
local LOG_RANGE = -math.log(VEL_MIN)

local function velocity_curve(x)
    local v = x ^ 0.8
    local out = VEL_MIN * math.exp(LOG_RANGE * v)
    return out
end

local function getFreq(note)
    local n = note - 69
    local f = 440 * 2 ^ (n / 12)
    return f / 44100
end

local function setPitch(ch)
    ch.f_base = getFreq(ch.pitch)
    ch.f = getFreq(ch.pitch + ch.pitchbend)
end

local function select_harmonic(f)
    -- local h = 44100 * f / 300
    -- h = math.floor(h)
    -- h = math.max(1, h)
    -- h = math.min(3, h)
    -- return h
    local h = 44100 * f / 340
    if h > 4 then
        return 3
    elseif h > 1.3 then
        return 2
    else
        return 1
    end
end

local function noteOn(note, vel, ev)
    local i = ev:getChannel()

    if #queue > 0 then
        transition = true
        t_time = 0.0
        prev_len = len
        prev_f = freq
    end

    table.insert(queue, i)
    active_channel = i

    local ch = channels[i]
    ch.pitch = note
    ch.pressure = 0

    setPitch(ch)
    -- freq = ch.f

    harmonic = select_harmonic(freq)
    print(harmonic)

    f_vibrato.reset_state()

    attack_env = velocity_curve(vel / 127)
    gate = 1.0
end

local function noteOff(note, ev)
    local i = ev:getChannel()
    local ch = channels[i]
    ch.pressure = 0

    for j, b in ipairs(queue) do
        if b == i then
            table.remove(queue, j)
            break
        end
    end

    if #queue > 0 then
        if active_channel == i then
            transition = true

            t_time = 0.0
            prev_f = freq
            prev_len = len

            local old_voice = queue[#queue]
            active_channel = old_voice
            -- freq = channels[old_voice].f
            harmonic = select_harmonic(channels[old_voice].f)

            f_vibrato.reset_state()
        end
    end
end

function processMidi(msg)
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
        if msg:getControlNumber() == 64 then
            pedal = msg:getControlValue() ~= 0
        end
    elseif msg:isPressure() then
        if ch > 1 then
            channels[ch].pressure = msg:getPressure() / 127
        end
    elseif msg:isNoteOn() then
        noteOn(msg:getNote(), msg:getVel(), msg)
    elseif msg:isNoteOff() then
        noteOff(msg:getNote(), msg)
    end
end

-- local function cubic(x)
--     if x <= -1 then
--         return -2.0 / 3.0
--     elseif x >= 1 then
--         return 2.0 / 3.0
--     else
--         return x - (x * x * x) / 3.0
--     end
-- end

local function softclip(x)
    -- return cubic(x + 0.4) - cubic(0.4)
    return math.tanh(x + 0.4) - math.tanh(0.4)
    -- return math.tanh(x)
end

function plugin.processBlock(samples, smax, midiBuf)
    for msg in midiBuf:eachEvent() do
        processMidi(msg)
    end

    local maxpres = 0

    for i = 1, 16 do
        local p = channels[i].pressure
        if p > maxpres then
            maxpres = p
        end
    end

    local ch = channels[active_channel]

    for i = 0, smax do
        -- update pressure env
        local a = attack
        if pres > ch.pressure then
            a = release
        end
        pres = pres - (pres - maxpres) * a

        -- update envelopes
        attack_env = attack_env * 0.999
        if #queue == 0 then
            gate = gate - (gate - maxpres) * release
        end

        -- update freq
        freq = freq - (freq - ch.f) * 0.002
        --freq = freq * (1 - 0.0001 * pres)

        local f_vib = f_vibrato.process(ch.pitchbend)

        local noise = math.random() - 0.5

        local s = noise * (0.03 + pres * 0.2 + pres * pres * 0.4 + attack_env * 0.5)

        local f2 = ch.f_base
        f2 = f2 * (1 + 0.03 * f_vib)

        -- r_filter.update({ f = f2 * 44100 })
        r_filter.update({ f = freq * 44100 })

        len = (harmonic / f2) - 1
        len = len * 0.98851

        local b_out = bore_delay.goBack(len)
        -- local b_out = bore_delay.goBack(len * (1 + 0.03 * prev_s))

        if transition then
            t_time = t_time + 1 / 44100
            if t_time > t_time_total then
                transition = false
            else
                local alpha = t_time / t_time_total

                local b_out2 = bore_delay.goBack(prev_len)

                b_out = (1.0 - alpha) * b_out2 + alpha * b_out

                -- local f3 = (1.0 - alpha) * prev_f + alpha * freq
                -- r_filter.update({ f = f3 * 44100 })
            end
        end

        b_out = f_lp.process(b_out)
        b_out = f_hp.process(b_out)

        local s2 = refl * b_out

        local p = pres_feedback * pres + attack_env * 0.6
        p = base_feedback + p * math.max(0, 1.0 + 2.0 * f_vib)

        local s3 = softclip(b_out * gate)
        -- s3 = s3 + 0.1 * math.max(0, s3) * s
        s3 = r_filter.process(s3)

        local fb = s2 + s3 * p + s
        prev_s = fb

        bore_delay.push(fb)

        local s_out = s3

        samples[0][i] = samples[0][i] + s_out * 0.2
        samples[1][i] = samples[1][i] + s_out * 0.2
    end
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
        name = "fb base",
        min = 0,
        max = 1.0,
        default = 0,
        changed = function(val)
            base_feedback = val
        end,
    },

    {
        name = "fb press",
        min = 0,
        max = 2.0,
        default = 0,
        changed = function(val)
            pres_feedback = val
        end,
    },

    {
        name = "bp resonance",
        min = 0.5,
        max = 2.0,
        default = 1.5,
        changed = function(val)
            -- pres_feedback = val
            r_filter.update({ Q = val })
        end,
    },

    {
        name = "pipe resonance",
        min = 0.0,
        max = 0.95,
        default = 0.7,
        changed = function(val)
            refl = val
        end,
    },
})
