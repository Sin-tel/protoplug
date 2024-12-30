require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
local cbFilter = require("include/dsp/cookbook filters")

local MAX_GRAINS = 20
local TWO_PI = 2.0 * math.pi

local maxLength = 3 * 44100
local fade_speed = 2.0
local grain_len = 0.2
local random_len = 0.5

local balance = 0.5
local length = 1
local feedback = 0
local gain = 1

local lpfilters = {}
local hpfilters = {}

local function crossfade(x)
	local x2 = 1 - x
	local a = x * x2
	local b = a * (1 + 1.4186 * a)
	local c = (b + x)
	local d = (b + x2)
	return c * c, d * d
	-- return x, (1.0 - x)
end

local function softclip(x)
	if x <= -1 then
		return -2.0 / 3.0
	elseif x >= 1 then
		return 2.0 / 3.0
	else
		return x - (x * x * x) / 3.0
	end
end

stereoFx.init()

function stereoFx.Channel:init()
	self.delayline = Line(maxLength)

	self.grains = {}

	for i = 1, MAX_GRAINS do
		self.grains = {
			ptr = 0,
			w_pos = 0,
			w_speed = 1,
			active = false,
		}
	end

	self.lp = cbFilter({
		type = "lp",
		f = 12000,
		gain = 0,
		Q = 0.7,
	})
	table.insert(lpfilters, self.lp)
	self.hp = cbFilter({
		type = "hp",
		f = 350,
		gain = 0,
		Q = 0.7,
	})
	table.insert(hpfilters, self.hp)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		local d = 0

		--trigger grains randomly
		local r = math.random()
		if r < 0.0001 then
			local k
			-- find available
			for j in ipairs(self.grains) do
				if not j.active then
					k = j
					break
				end
			end
			-- schedule
			if k then
				local g = self.grains[k]
				g.ptr = length * 44100

				g.speed = 1.0

				local l = (grain_len * 44100) * (1 + random_len * (math.random() - 0.5))
				g.w_speed = 1 / l
				g.active = true
			end
		end

		--render
		for _, v in ipairs(self.grains) do
			if v.active then
				v.w_pos = v.w_pos + v.w_speed
				v.ptr = v.ptr + (v.speed - 1.0)

				if v.w_pos > 1.0 then
					v.active = false
				else
					-- window
					local a = 0.5 - 0.5 * math.cos(TWO_PI * v.w_pos)
					d = d + a * self.delayline.goBack(v.start)
				end
			end
		end

		d = self.lp.process(d)
		d = self.hp.process(d)
		d = softclip(d)

		self.delayline.push(s + d * feedback)
		samples[i] = s * (1.0 - balance) + d * balance
	end
end

local function updateFilters(filters, args)
	for _, f in pairs(filters) do
		f.update(args)
	end
end

params = plugin.manageParams({
	{
		name = "Dry/Wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "Length",
		max = 2,
		changed = function(val)
			length = val
		end,
	},
	{
		name = "Feedback",
		max = 1.2,
		changed = function(val)
			feedback = val
		end,
	},
	{
		name = "Grain length",
		min = 0.02,
		max = 1.0,
		changed = function(val)
			grain_len = val
		end,
	},
	{
		name = "Grain randomize",
		min = 0.0,
		max = 1.0,
		changed = function(val)
			random_len = val
		end,
	},
	{
		name = "Highpass",
		min = 0,
		max = 1000,
		changed = function(val)
			updateFilters(hpfilters, { f = val })
		end,
	},
	{
		name = "Lowpass",
		min = 5000,
		max = 22000,
		changed = function(val)
			updateFilters(lpfilters, { f = val })
		end,
	},
})
