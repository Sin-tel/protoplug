require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local s = 0
local t = 0
local state = 0
local track = 440

local hyst = 0.01

local mag = 1.0

local bp = cbFilter({
	type = "bp",
	f = 440,
	Q = 2,
	gain = 0,
})
local bp2 = cbFilter({
	type = "bp",
	f = 440,
	Q = 2,
	gain = 0,
})

function f_to_pitch(p)
	return 60 + 12 * math.log(p / 261.625565301) / math.log(2)
end

function plugin.processBlock(samples, smax)
	print(f_to_pitch(track), track)
	track = math.min(track, 5000)
	track = math.max(track, 20)
	bp.update({ f = track })
	bp2.update({ f = track })
	for i = 0, smax do
		local l = samples[0][i]
		local r = samples[1][i]

		t = t + 1 / 44100

		l = bp2.process(bp.process(l))

		mag = mag * 0.999 + 0.001 * math.abs(l)

		l = 0.5 * l / mag

		if state == 0 then
			if l > hyst then
				--leading edge
				state = 1

				track = track * smooth + (1 / t) * (1 - smooth)

				t = 0
			end
		else
			if l < -hyst then
				state = 0
			end
		end

		--if p <= 0 and l > 0 then
		--    track = t
		--end

		local prev = l

		samples[0][i] = state * 0.5
		samples[1][i] = l
	end
end

params = plugin.manageParams({

	{
		name = "hysteresis",
		min = 0,
		max = 0.2,
		changed = function(val)
			hyst = val
		end,
	},
	{
		name = "smooth",
		min = 0,
		max = 10,
		changed = function(val)
			smooth = 1 - math.exp(-val)
		end,
	},
	{
		name = "reset",
		min = 20,
		max = 5000,
		changed = function(val)
			track = val
		end,
	},
})
