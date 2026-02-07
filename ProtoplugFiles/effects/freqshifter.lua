require("include/protoplug")
local Hilbert = require("include/dsp/hilbert")

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

local function mul(x, y)
	return diode(abs(x + 0.5 * y)) - diode(abs(x - 0.5 * y))
end

stereoFx.init()
function stereoFx.Channel:init()
	self.hilbert = Hilbert.new()
	self.accum = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local x = samples[i]

		local r, c

		r, c = self.hilbert.process(x)
		self.accum = self.accum + freq
		self.accum = self.accum % 1
		local phase = TWO_PI * self.accum

		-- standard multiplier:
		-- local s = r * math.sin(phase) + c * math.cos(phase)

		local s = mul(r, math.sin(phase)) + mul(c, math.cos(phase))

		samples[i] = s
	end
end

params = plugin.manageParams({
	{
		name = "freq",
		min = -100,
		max = 100,
		default = 0,
		changed = function(val)
			freq = val / 44100
		end,
	},
})

params.resetToDefaults()
