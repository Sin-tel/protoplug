--[[

Opamp/OTA transfer function:

tanh(g*(x0 - x1))

Where g is some internal gain

In negative feedback configuration:

y = tanh(g*(x - y))

Solve using Newton iteration:

f(x) = tanh(g*(u - x)) - x = 0
h(x) = df/dx  = -a*sech(a*(u - x))^2 - 1

Newton update:

x' = x - f(x) / h(x)

]]

require("include/protoplug")

local gain = 1
local iters = 10

local tanh = math.tanh
local cosh = math.cosh

local function clip(x)
	local s = math.min(math.max(x, -5 / 4), 5 / 4)
	return s - (256. / 3125.) * s ^ 5
end

local function sech2(x)
	local u = cosh(x)
	return 1 / (u * u)
end

local function newton_iter(x, u)
	local f = tanh(gain * (u - x)) - x
	local h = -gain * sech2(gain * (u - x)) - 1

	return x - f / h
end

stereoFx.init()
function stereoFx.Channel:init()
	--
end
function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local x = samples[i]

		-- Take x as initial guess
		local s = x

		for j = 1, iters do
			s = newton_iter(s, x)
		end

		-- s = clip(0.927 * s)

		samples[i] = s
	end
end

params = plugin.manageParams({
	{
		name = "gain (dB)",
		min = 0,
		max = 60,
		changed = function(val)
			gain = 10 ^ (val / 20)
		end,
	},
	{
		name = "iters",
		type = "int",
		min = 1,
		max = 20,
		default = 10,
		changed = function(val)
			iters = val
		end,
	},
})
