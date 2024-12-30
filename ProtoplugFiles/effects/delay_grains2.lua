require("include/protoplug")
local Line = require("include/dsp/fdelay_line")
local cbFilter = require("include/dsp/cookbook filters")

local MAX_GRAINS = 20
local TWO_PI = 2.0 * math.pi

local maxLength = 3 * 44100
local fade_speed = 2.0
local grain_len = 0.2
local random_pos = 0.5
local random_pitch = 0.5

local balance = 0.5
local length = 1
local feedback = 0
local gain = 1

local lpfilters = {}
local hpfilters = {}

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
		self.grains[i] = {
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
		if r < 0.002 then
			local k
			-- find available
			for j, v in ipairs(self.grains) do
				if not v.active then
					k = j
					break
				end
			end
			-- schedule
			if k then
				local g = self.grains[k]
				g.ptr = (length * 44100) * (1 + random_pos * (math.random() - 0.5))
				g.w_pos = 0.0

				local r_pitch = math.exp(random_pitch * (math.random() - 0.5))
				g.speed = 1.0 * r_pitch
				if math.random() < 0.03 then
					g.speed = g.speed * 2.0
				end

				local l = grain_len * 44100
				g.w_speed = 1 / l
				g.active = true
			end
		end

		local env_sq = 0

		--render
		for _, v in ipairs(self.grains) do
			if v.active then
				v.w_pos = v.w_pos + v.w_speed
				v.ptr = v.ptr + (1.0 - v.speed)

				if v.w_pos > 1.0 then
					v.active = false
				else
					-- window
					local a = 0.5 - 0.5 * math.cos(TWO_PI * v.w_pos)
					d = d + a * self.delayline.goBack(v.ptr)
					env_sq = env_sq + a * a
				end
			end
		end

		local norm = 1.0 / (math.sqrt(env_sq) + 0.1)

		d = d * norm

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
		min = 0.0,
		max = 1.0,
		changed = function(val)
			grain_len = 50 ^ (val - 1)
		end,
	},
	{
		name = "Grain randomize",
		min = 0.0,
		max = 1.0,
		changed = function(val)
			random_pos = val
		end,
	},
	{
		name = "Pitch randomize",
		min = 0.0,
		max = 1.0,
		changed = function(val)
			random_pitch = val * 0.2
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
