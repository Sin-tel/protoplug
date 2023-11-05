--[[
midi version
remaps 12 edo input to another edo

]]

require("include/protoplug")

local edo = 34

local fifth = 12 * math.floor(edo * math.log(3 / 2) / math.log(2) + 0.5) / edo

print(fifth)

local third = 12 * math.floor(edo * math.log(5 / 4) / math.log(2) + 0.5) / edo

print(third)

local notes = {}

local cx = 0
local cy = 0

local names = { "F", "C", "G", "D", "A", "E", "B" }

require("include/protoplug")

local blockEvents = {}

local function temper(note)
	local index = note % 12

	local x = index * 7 - cx
	local y = x / 4 - cy

	x = x % 4
	y = y % 3

	y = y - x * 0.25

	if x > 2.0 then
		x = x - 4
		y = y + 1
	end

	if y > 1.5 then
		y = y - 3
	end

	local crx = cx
	local cry = cy

	cx = cx + x * 0.2
	cy = cy + y * 0.7

	local px = math.floor(crx + x + 0.5)
	local py = math.floor(cry + y + 0.5)

	local sharp = math.floor((px + py * 4 + 1) / 7)
	local comma = py

	local sh = ""
	if sharp > 0 then
		sh = string.rep("#", sharp)
	elseif sharp < 0 then
		sh = string.rep("b", -sharp)
	end

	local cm = ""
	if comma > 0 then
		cm = string.rep("-", comma)
	elseif comma < 0 then
		cm = string.rep("+", -comma)
	end

	print(names[(px + py * 4 + 1) % 7 + 1] .. sh .. cm)
	--print(px,py)
	--print(math.floor((x)*100)/100,math.floor((y)*100)/100)
	--print(math.floor((cx)*100)/100,math.floor((cy)*100)/100)
	--print(note + px*(fifth - 7) + py*(third - 4))

	return note + px * (fifth - 7) + py * (third - 4)
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

	local tempered = temper(nt)
	local tempnote = math.floor(edo * (tempered - 69) / 12 + 0.50001) + 69

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
