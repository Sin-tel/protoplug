--[[
play an EDO in launchpad using isomorphic layout
]]

require("include/protoplug")

local blockEvents = {}

notes = {}

left = 2
up = 9
edo = 22

velocity = 80

function getXY(note)
    local x = note % 16 - 3
    local y = 4 - math.floor(note / 16)
    --if x < 8 then -- dont send rightmost buttons
    return x, y
    --end
end

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

function noteOn(note)
    local nt = note:getNote()

    local x, y = getXY(nt)

    if x then
        print(x, y)

        local tempnote = 60 + left * x + up * y

        local ch, sendnote = getch(tempnote)

        vel = velocity

        notes[nt] = tempnote

        local newEv = midi.Event.noteOn(ch, sendnote, vel)

        table.insert(blockEvents, newEv)
    end
end

function noteOff(note)
    local nt = note:getNote()
    local tempnote = notes[nt]

    if tempnote then
        local ch, sendnote = getch(tempnote)

        local newEv = midi.Event.noteOff(ch, sendnote)
        table.insert(blockEvents, newEv)
    end
end
