require("include/protoplug")

local attack = 0.005
local release = 0.005

local pedal = false

local TWOPI = 2 * math.pi

local active_channel = 1

local freq = 0
local pres = 0
local phase = 0

local prev_s = 0

local function newChannel()
    local new = {}

    new.pressure = 0
    new.f = 0
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

local function getFreq(note)
    local n = note - 69
    local f = 440 * 2 ^ (n / 12)
    return f / 44100
end

local function setPitch(ch)
    ch.f = getFreq(ch.pitch + ch.pitchbend)
end

local function noteOn(note, vel, ev)
    local i = ev:getChannel()

    table.insert(queue, i)
    active_channel = i

    local ch = channels[i]
    ch.pitch = note
    ch.pressure = 0

    setPitch(ch)
    freq = ch.f
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
        local old_voice = queue[#queue]
        active_channel = old_voice
        freq = channels[old_voice].f
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

        -- update freq
        freq = freq - (freq - ch.f) * 0.002

        phase = phase + (freq * TWOPI)
        local out = math.sin(phase + prev_s * (pres * 0.5 + 0.2))

        prev_s = out

        local samp = out * pres

        samples[0][i] = samples[0][i] + samp * 0.5
        samples[1][i] = samples[1][i] + samp * 0.5
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
})
