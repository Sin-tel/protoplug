--[[
set up only lights for launchpad
]]

require("include/protoplug")

local blockEvents = {}

notes = {}

startup = true

REDL = 13
RED = 15
AMBERL = 29
AMBER = 63
YELLOW = 62
GREENL = 28
GREEN = 60
OFF = 12

function plugin.processBlock(samples, smax, midiBuf)
    blockEvents = {}

    for ev in midiBuf:eachEvent() do
        if ev:isNoteOn() then
            noteOn(ev)
        elseif ev:isNoteOff() then
            noteOff(ev)
        else
            table.insert(blockEvents, midi.Event(ev))
        end
    end
    if startup then
        startup = false
        setlights()
    end
    -- fill midi buffer with prepared notes
    midiBuf:clear()
    if #blockEvents > 0 then
        for _, e in ipairs(blockEvents) do
            midiBuf:addEvent(e)
        end
    end
end

function setlight(x, y, color)
    local nt = x + y * 16
    print(nt)
    notes[nt] = color
    local newEv = midi.Event.noteOn(1, nt, color)
    table.insert(blockEvents, newEv)
end

function setlights()
    for i = 0, 7 do
        setlight(1, i, AMBERL)
        setlight(3, i, AMBERL)
        setlight(5, i, AMBERL)
        setlight(7, i, AMBERL)
    end

    setlight(1, 6, RED)
    setlight(3, 4, RED)
    setlight(5, 2, RED)
    setlight(7, 0, RED)
end

function noteOn(note)
    local nt = note:getNote()
    print(nt)

    local ch = 1

    vel = GREEN

    local newEv = midi.Event.noteOn(ch, nt, vel)

    table.insert(blockEvents, newEv)
end

function noteOff(note)
    local nt = note:getNote()

    local ch = 1

    vel = notes[nt] or OFF

    local newEv = midi.Event.noteOn(ch, nt, vel)
    table.insert(blockEvents, newEv)
end
