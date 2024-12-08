require("include/protoplug")

local coefs = require("effects/lattice_coefs")

local c_len = #coefs["a"]

local set_1 = "a"
local set_2 = "i"

stereoFx.init()

local l_set = 0

function stereoFx.Channel:init()
	self.lf = {}
	self.lg = {}
	for i = 0, c_len do
		self.lf[i] = 0
		self.lg[i] = 0
	end

	self.l_i = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		self.lf[c_len] = s
		self.l_i = self.l_i - (self.l_i - l_set) * 0.0003
		for m = c_len, 1, -1 do
			local k = (1 - self.l_i) * coefs[set_1][m] + self.l_i * coefs[set_2][m]
			self.lf[m - 1] = self.lf[m] - k * self.lg[m - 1]
			self.lg[m] = k * self.lf[m - 1] + self.lg[m - 1]
		end
		local out = self.lf[0]
		self.lg[0] = out

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "a - i",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			l_set = val
		end,
	},
})
