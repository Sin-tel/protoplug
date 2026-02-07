require("include/protoplug")
local freq = 100

local TWO_PI = 2 * math.pi

local abs = math.abs

local v0 = 0.15
local l = 0.45

local function diode(x)
	local v = x - v0
	if v < 0 then
		return 0
	elseif v < l then
		return v * v / (2 * l)
	else
		return x - (v0 + l) + l * l / (2 * l)
	end
end

stereoFx.init()
function stereoFx.Channel:init()
	self.accum = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local x = samples[i]

		self.accum = self.accum + freq
		self.accum = self.accum % 1
		local phase = TWO_PI * self.accum
		local mod = math.sin(phase)

		-- local s = mod * x
		local s = diode(abs(x + 0.5 * mod)) - diode(abs(x - 0.5 * mod))
		-- local s = diode(abs(mod + 0.5 * x)) - diode(abs(mod - 0.5 * x))

		samples[i] = s
	end
end

params = plugin.manageParams({
	{
		name = "freq",
		min = 0,
		max = 8000,
		default = 0,
		changed = function(val)
			freq = val / 44100
		end,
	},

	{
		name = "v0",
		min = 0,
		max = 1,
		default = 0.15,
		changed = function(val)
			v0 = val
		end,
	},

	{
		name = "l",
		min = 0,
		max = 1,
		default = 0.45,
		changed = function(val)
			l = val
		end,
	},
})

-- params.resetToDefaults()
