--[[
MIDI mapper for linnstrument in channel per note mode
it can do polyphonic aftertouch, pitchbends are good enough to do vibrato but sliding is probably awkward
]]

require("include/protoplug")

notes = {}

up = 13
left = 5
edo = 31

lastch = 0

local blockEvents = {}

function plugin.processBlock(samples, smax, midiBuf)
    blockEvents = {}

    for ev in midiBuf:eachEvent() do
        if ev:isNoteOn() then
            noteOn(ev)
        elseif ev:isNoteOff() then
            noteOff(ev)
        elseif ev:isAftertouch() then
            aftertouch(ev)
        elseif ev:isPitchBend() then
            if ev:getChannel() == lastch then
                table.insert(blockEvents, midi.Event(ev))
            end
        else
            table.insert(blockEvents, midi.Event(ev))
        end
    end
    -- fill midi buffer with prepared notes
    midiBuf:clear()
    if #blockEvents > 0 then
        for _, e in ipairs(blockEvents) do
            midiBuf:addEvent(e)
        end
    end
end

function getch(nt)
    local ch = 1
    if nt < 0 then
        ch = 17
    end
    while nt < 0 do
        nt = nt + edo
        ch = ch - 1
    end
    while nt >= 128 do
        nt = nt - edo
        ch = ch + 1
    end
    return ch, nt
end

function getNote(nt, ch)
    x = nt - ch * 5 - 25
    y = ch - 4

    tempnote = x * left + y * up + 69

    return getch(tempnote)
end

function aftertouch(ev)
    local nt = ev:getNote()
    local ch = ev:getChannel()

    ch, sendnote = getNote(nt, ch)

    local newEv = midi.Event.aftertouch(ch, sendnote, ev:getVel())
    table.insert(blockEvents, newEv)
end

function noteOn(ev)
    local nt = ev:getNote()
    local ch = ev:getChannel()

    lastch = ch

    ch, sendnote = getNote(nt, ch)

    local newEv = midi.Event.noteOn(ch, sendnote, ev:getVel())
    table.insert(blockEvents, newEv)
end

function noteOff(ev)
    local nt = ev:getNote()
    local ch = ev:getChannel()

    ch, sendnote = getNote(nt, ch)

    if sendnote then
        local newEv = midi.Event.noteOff(ch, sendnote)
        table.insert(blockEvents, newEv)
    end
end
