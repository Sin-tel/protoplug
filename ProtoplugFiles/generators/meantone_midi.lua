--[[
midi version
output edo must support meantone (in the wide sense: superpyth and mavila also work)

]]

require("include/protoplug")

local edo = 31
local fifth = 12 * math.floor(edo * math.log(3 / 2) / math.log(2) + 0.5) / edo

print(fifth)

local notes = {}
local center = 0

require("include/protoplug")

local blockEvents = {}

local function temper(note)
	local index = note % 12
	local oct = note - index

	local cround = math.floor(center + 0.5)

	local pos = ((index * 7 + 5 - cround) % 12 - 5)

	if pos ~= 6 then
		center = center + pos * 0.25
	end

	--print(cround,pos,((pos + cround)*6.95)%12)
	print(cround, pos, index + (pos + cround) * (fifth - 7))
	--print(fifth)

	return oct + index + (pos + cround) * (fifth - 7)
end

local function getch(nt)
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

local function noteOn(root)
	local nt = root:getNote()

	local tempnote = math.floor(edo * (temper(nt) - 69) / 12 + 0.5) + 69

	local ch, sendnote = getch(tempnote)

	notes[nt] = tempnote

	local newEv = midi.Event.noteOn(ch, sendnote, root:getVel())
	table.insert(blockEvents, newEv)
end

local function noteOff(root)
	local nt = root:getNote()
	local tempnote = notes[nt]

	if tempnote then
		local ch, sendnote = getch(tempnote)

		local newEv = midi.Event.noteOff(ch, sendnote)
		table.insert(blockEvents, newEv)
	end
end

function plugin.processBlock(samples, smax, midiBuf)
	blockEvents = {}

	-- analyse midi buffer and prepare a chord for each note
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
