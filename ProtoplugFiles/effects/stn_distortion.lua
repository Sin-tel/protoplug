local script = require("include/core/script")
require("include/protoplug")
local json = require("include/json")

local function readfile(filename)
	local file = assert(io.open(filename, "r"))
	local content = file:read("*a")
	file:close()
	return content
end

local weights = json.decode(readfile(script.protoplugDir .. "/effects/stn_distortion_w.json"))

local l1_w = weights["network.0.weight"] -- 8*3
local l1_b = weights["network.0.bias"] -- 8
local l2_w = weights["network.2.weight"] -- 8*8
local l2_b = weights["network.2.bias"] -- 8
local l3_w = weights["network.4.weight"] -- 8*2
local l3_b = weights["network.4.bias"] -- 2

local gain = 0

local dt = 1.0

local function elu(x)
	if x >= 0 then
		return x
	else
		return math.exp(x) - 1.0
	end
end

local function forward(u, s1, s2)
	-- stylua: ignore start

	local y1, y2, y3, y4, y5, y6, y7, y8
	local z1, z2, z3, z4, z5, z6, z7, z8

	y1 = l1_w[1][1] * u + l1_w[1][2] * s1 + l1_w[1][3] * s2 + l1_b[1]
	y2 = l1_w[2][1] * u + l1_w[2][2] * s1 + l1_w[2][3] * s2 + l1_b[2]
	y3 = l1_w[3][1] * u + l1_w[3][2] * s1 + l1_w[3][3] * s2 + l1_b[3]
	y4 = l1_w[4][1] * u + l1_w[4][2] * s1 + l1_w[4][3] * s2 + l1_b[4]
	y5 = l1_w[5][1] * u + l1_w[5][2] * s1 + l1_w[5][3] * s2 + l1_b[5]
	y6 = l1_w[6][1] * u + l1_w[6][2] * s1 + l1_w[6][3] * s2 + l1_b[6]
	y7 = l1_w[7][1] * u + l1_w[7][2] * s1 + l1_w[7][3] * s2 + l1_b[7]
	y8 = l1_w[8][1] * u + l1_w[8][2] * s1 + l1_w[8][3] * s2 + l1_b[8]

	y1 = elu(y1)
	y2 = elu(y2)
	y3 = elu(y3)
	y4 = elu(y4)
	y5 = elu(y5)
	y6 = elu(y6)
	y7 = elu(y7)
	y8 = elu(y8)

	z1 = l2_w[1][1] * y1 + l2_w[1][2] * y2 + l2_w[1][3] * y3 + l2_w[1][4] * y4 + l2_w[1][5] * y5 + l2_w[1][6] * y6 + l2_w[1][7] * y7 + l2_w[1][8] * y8 + l2_b[1]
	z2 = l2_w[2][1] * y1 + l2_w[2][2] * y2 + l2_w[2][3] * y3 + l2_w[2][4] * y4 + l2_w[2][5] * y5 + l2_w[2][6] * y6 + l2_w[2][7] * y7 + l2_w[2][8] * y8 + l2_b[2]
	z3 = l2_w[3][1] * y1 + l2_w[3][2] * y2 + l2_w[3][3] * y3 + l2_w[3][4] * y4 + l2_w[3][5] * y5 + l2_w[3][6] * y6 + l2_w[3][7] * y7 + l2_w[3][8] * y8 + l2_b[3]
	z4 = l2_w[4][1] * y1 + l2_w[4][2] * y2 + l2_w[4][3] * y3 + l2_w[4][4] * y4 + l2_w[4][5] * y5 + l2_w[4][6] * y6 + l2_w[4][7] * y7 + l2_w[4][8] * y8 + l2_b[4]
	z5 = l2_w[5][1] * y1 + l2_w[5][2] * y2 + l2_w[5][3] * y3 + l2_w[5][4] * y4 + l2_w[5][5] * y5 + l2_w[5][6] * y6 + l2_w[5][7] * y7 + l2_w[5][8] * y8 + l2_b[5]
	z6 = l2_w[6][1] * y1 + l2_w[6][2] * y2 + l2_w[6][3] * y3 + l2_w[6][4] * y4 + l2_w[6][5] * y5 + l2_w[6][6] * y6 + l2_w[6][7] * y7 + l2_w[6][8] * y8 + l2_b[6]
	z7 = l2_w[7][1] * y1 + l2_w[7][2] * y2 + l2_w[7][3] * y3 + l2_w[7][4] * y4 + l2_w[7][5] * y5 + l2_w[7][6] * y6 + l2_w[7][7] * y7 + l2_w[7][8] * y8 + l2_b[7]
	z8 = l2_w[8][1] * y1 + l2_w[8][2] * y2 + l2_w[8][3] * y3 + l2_w[8][4] * y4 + l2_w[8][5] * y5 + l2_w[8][6] * y6 + l2_w[8][7] * y7 + l2_w[8][8] * y8 + l2_b[8]

	z1 = elu(z1)
	z2 = elu(z2)
	z3 = elu(z3)
	z4 = elu(z4)
	z5 = elu(z5)
	z6 = elu(z6)
	z7 = elu(z7)
	z8 = elu(z8)

	s1 = s1 + dt*(l3_w[1][1] * z1 + l3_w[1][2] * z2 + l3_w[1][3] * z3 + l3_w[1][4] * z4 + l3_w[1][5] * z5 + l3_w[1][6] * z6 + l3_w[1][7] * z7 + l3_w[1][8] * z8 + l3_b[1])
	s2 = s2 + dt*(l3_w[2][1] * z1 + l3_w[2][2] * z2 + l3_w[2][3] * z3 + l3_w[2][4] * z4 + l3_w[2][5] * z5 + l3_w[2][6] * z6 + l3_w[2][7] * z7 + l3_w[2][8] * z8 + l3_b[2])
	-- stylua: ignore end

	return s1, s2
end

stereoFx.init()
function stereoFx.Channel:init()
	self.s1 = 0
	self.s2 = 0
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local u = 0.1 * gain * samples[i]
		self.s1, self.s2 = forward(u, self.s1, self.s2)

		samples[i] = 2 * self.s1 / gain
	end
end

params = plugin.manageParams({
	{
		name = "amp",
		min = 1,
		max = 10,
		changed = function(val)
			gain = val
		end,
	},
})
