require("include/protoplug")
local Line = require("include/dsp/fdelay_line")

local k_filter = 0.625
local balance = 1.0

local max_num = 70
local l = max_num
local feedback = 0
local coupling = 1
local master_freq = 1

local channels = {}

stereoFx.init()
function stereoFx.Channel:init()
	table.insert(channels, self)
	self.delays = {}
	self.len = {}
	self.filter = {}
	for i = 1, max_num do
		self.delays[i] = Line(2000)

		self.filter[i] = 0

		self.len[i] = math.random() * 1400 + 500
	end

	self.last = 0

	self.prev = 0
end

local function randomize()
	for _, v in ipairs(channels) do
		for i = 1, max_num do
			v.len[i] = math.random() * 1800 + 100
		end
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for k = 0, smax do
		local input = samples[k]

		local s = input

		local tot = 0

		local u = -self.prev

		--u = math.max(0, u)

		-- softmax
		u = u + math.sqrt(u * u + 0.3)

		for i = 1, l do
			local d = self.delays[i].goBack(self.len[i] * master_freq - u)

			-- one pole lowpass
			local v = self.filter[i] + (d - self.filter[i]) * k_filter

			self.filter[i] = v

			tot = tot + v
		end

		tot = tot / l

		self.prev = tot

		local f1 = feedback
		local f2 = coupling * 2 * feedback

		for i = 1, l do
			local v = self.filter[i]

			self.delays[i].push(s + v * f1 - tot * f2)
		end

		self.last = s
		local signal = tot

		samples[k] = input * (1.0 - balance) + signal * balance
	end
end

local params = plugin.manageParams({
	{
		name = "Dry/Wet",
		min = 0,
		max = 1,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "number",
		min = 0,
		max = max_num,
		type = "int",
		changed = function(val)
			l = val
		end,
	},
	{
		name = "filter",
		min = 0,
		max = 1,
		changed = function(val)
			k_filter = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	{
		name = "feedback",
		min = 0,
		max = 1,
		changed = function(val)
			feedback = 1 - (1 - val) * (1 - val) * (1 - val)
		end,
	},
	{
		name = "frequency",
		min = 0.1,
		max = 1,
		changed = function(val)
			master_freq = val
		end,
	},
	{
		name = "randomize",
		min = 0,
		max = 1,
		changed = function(val)
			randomize()
		end,
	},
})
