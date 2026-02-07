-- trigger note-ons for the key mechanisms on woodwinds

require("include/protoplug")

local blockEvents = {}

local notes = {}

local function noteOn(event)
	local note = event:getNote()

	local ch = 1

	local vel = event:getVel()

	if #notes ~= 0 then
		local newEv = midi.Event.noteOn(ch, note, vel)
		table.insert(blockEvents, newEv)
	end
	table.insert(notes, note)
end

local function noteOff(event)
	local note = event:getNote()

	local ch = 1

	if note == notes[#notes] and #notes > 1 then
		local newEv = midi.Event.noteOn(ch, note, 64)
		table.insert(blockEvents, newEv)
	end

	for i = #notes, 1, -1 do
		if notes[i] == note then
			table.remove(notes, i)
		end
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
