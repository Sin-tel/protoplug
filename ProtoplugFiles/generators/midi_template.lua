--[[
midi processor example
transposes incoming midi one semitone
]]

require("include/protoplug")

local blockEvents = {}

local notes = {}

local function noteOn(note)
	local nt = note:getNote()

	local sendnote = nt + 1

	local ch = 1

	local vel = note:getVel()

	notes[nt] = sendnote

	local newEv = midi.Event.noteOn(ch, sendnote, vel)

	table.insert(blockEvents, newEv)
end

local function noteOff(note)
	local nt = note:getNote()

	local ch = 1

	local sendnote = notes[nt]

	if sendnote then
		local newEv = midi.Event.noteOff(ch, sendnote)
		table.insert(blockEvents, newEv)
	end
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
