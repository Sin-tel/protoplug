local script = require("include/core/script")
require("include/protoplug")
local json = require("include/json")
local Upsampler = require("include/dsp/upsampler_11")
local Downsampler = require("include/dsp/downsampler_31")
local Filter = require("include/dsp/cookbook_svf")

local function readfile(filename)
	local file = assert(io.open(filename, "r"))
	local content = file:read("*a")
	file:close()
	return content
end

local weights = json.decode(readfile(script.protoplugDir .. "/effects/stn_distortion_w2.json"))

local l1_w = weights["network.0.weight"]
local l1_b = weights["network.0.bias"]
local l2_w = weights["network.2.weight"]
local l2_b = weights["network.2.bias"]
local l3_w = weights["network.4.weight"]
local l3_b = weights["network.4.bias"]
local proj_w = weights["proj.weight"]

local gain = 0

local tanh = math.tanh

local function forward(u_prev, u, s1, s2)
	-- stylua: ignore start

	local y1, y2, y3, y4, y5, y6, y7, y8
	y1 = l1_w[1][1] * u_prev + l1_w[1][2] * u + l1_w[1][3] * s1 + l1_w[1][4] * s2 + l1_b[1]
	y2 = l1_w[2][1] * u_prev + l1_w[2][2] * u + l1_w[2][3] * s1 + l1_w[2][4] * s2 + l1_b[2]
	y3 = l1_w[3][1] * u_prev + l1_w[3][2] * u + l1_w[3][3] * s1 + l1_w[3][4] * s2 + l1_b[3]
	y4 = l1_w[4][1] * u_prev + l1_w[4][2] * u + l1_w[4][3] * s1 + l1_w[4][4] * s2 + l1_b[4]
	y5 = l1_w[5][1] * u_prev + l1_w[5][2] * u + l1_w[5][3] * s1 + l1_w[5][4] * s2 + l1_b[5]
	y6 = l1_w[6][1] * u_prev + l1_w[6][2] * u + l1_w[6][3] * s1 + l1_w[6][4] * s2 + l1_b[6]
	y7 = l1_w[7][1] * u_prev + l1_w[7][2] * u + l1_w[7][3] * s1 + l1_w[7][4] * s2 + l1_b[7]
	y8 = l1_w[8][1] * u_prev + l1_w[8][2] * u + l1_w[8][3] * s1 + l1_w[8][4] * s2 + l1_b[8]

	y1 = tanh(y1)
	y2 = tanh(y2)
	y3 = tanh(y3)
	y4 = tanh(y4)
	y5 = tanh(y5)
	y6 = tanh(y6)
	y7 = tanh(y7)
	y8 = tanh(y8)

	local z1, z2, z3, z4, z5, z6, z7, z8
	z1 = l2_w[1][1] * y1 + l2_w[1][2] * y2 + l2_w[1][3] * y3 + l2_w[1][4] * y4 + l2_w[1][5] * y5 + l2_w[1][6] * y6 + l2_w[1][7] * y7 + l2_w[1][8] * y8 + l2_b[1]
	z2 = l2_w[2][1] * y1 + l2_w[2][2] * y2 + l2_w[2][3] * y3 + l2_w[2][4] * y4 + l2_w[2][5] * y5 + l2_w[2][6] * y6 + l2_w[2][7] * y7 + l2_w[2][8] * y8 + l2_b[2]
	z3 = l2_w[3][1] * y1 + l2_w[3][2] * y2 + l2_w[3][3] * y3 + l2_w[3][4] * y4 + l2_w[3][5] * y5 + l2_w[3][6] * y6 + l2_w[3][7] * y7 + l2_w[3][8] * y8 + l2_b[3]
	z4 = l2_w[4][1] * y1 + l2_w[4][2] * y2 + l2_w[4][3] * y3 + l2_w[4][4] * y4 + l2_w[4][5] * y5 + l2_w[4][6] * y6 + l2_w[4][7] * y7 + l2_w[4][8] * y8 + l2_b[4]
	z5 = l2_w[5][1] * y1 + l2_w[5][2] * y2 + l2_w[5][3] * y3 + l2_w[5][4] * y4 + l2_w[5][5] * y5 + l2_w[5][6] * y6 + l2_w[5][7] * y7 + l2_w[5][8] * y8 + l2_b[5]
	z6 = l2_w[6][1] * y1 + l2_w[6][2] * y2 + l2_w[6][3] * y3 + l2_w[6][4] * y4 + l2_w[6][5] * y5 + l2_w[6][6] * y6 + l2_w[6][7] * y7 + l2_w[6][8] * y8 + l2_b[6]
	z7 = l2_w[7][1] * y1 + l2_w[7][2] * y2 + l2_w[7][3] * y3 + l2_w[7][4] * y4 + l2_w[7][5] * y5 + l2_w[7][6] * y6 + l2_w[7][7] * y7 + l2_w[7][8] * y8 + l2_b[7]
	z8 = l2_w[8][1] * y1 + l2_w[8][2] * y2 + l2_w[8][3] * y3 + l2_w[8][4] * y4 + l2_w[8][5] * y5 + l2_w[8][6] * y6 + l2_w[8][7] * y7 + l2_w[8][8] * y8 + l2_b[8]

	z1 = tanh(z1)
	z2 = tanh(z2)
	z3 = tanh(z3)
	z4 = tanh(z4)
	z5 = tanh(z5)
	z6 = tanh(z6)
	z7 = tanh(z7)
	z8 = tanh(z8)

	local y_res, s1_res, s2_res
	y_res  = proj_w[1][1] * u_prev + proj_w[1][2] * u + proj_w[1][3] * s1 + proj_w[1][4] * s2
	s1_res = proj_w[2][1] * u_prev + proj_w[2][2] * u + proj_w[2][3] * s1 + proj_w[2][4] * s2
	s2_res = proj_w[3][1] * u_prev + proj_w[3][2] * u + proj_w[3][3] * s1 + proj_w[3][4] * s2

	local y
	y  = y_res  + l3_w[1][1] * z1 + l3_w[1][2] * z2 + l3_w[1][3] * z3 + l3_w[1][4] * z4 + l3_w[1][5] * z5 + l3_w[1][6] * z6 + l3_w[1][7] * z7 + l3_w[1][8] * z8 + l3_b[1]
	s1 = s1_res + l3_w[2][1] * z1 + l3_w[2][2] * z2 + l3_w[2][3] * z3 + l3_w[2][4] * z4 + l3_w[2][5] * z5 + l3_w[2][6] * z6 + l3_w[2][7] * z7 + l3_w[2][8] * z8 + l3_b[2]
	s2 = s2_res + l3_w[3][1] * z1 + l3_w[3][2] * z2 + l3_w[3][3] * z3 + l3_w[3][4] * z4 + l3_w[3][5] * z5 + l3_w[3][6] * z6 + l3_w[3][7] * z7 + l3_w[3][8] * z8 + l3_b[3]
	-- stylua: ignore end

	return y, s1, s2
end

stereoFx.init()
function stereoFx.Channel:init()
	self.s1 = 0
	self.s2 = 0
	self.u_prev = 0

	self.upsampler = Upsampler()
	self.downsampler = Downsampler()

	self.high = Filter({ type = "hp", f = 16, gain = 0, Q = 0.7 })
	self.shelf = Filter({ type = "hs", f = 7000, gain = 6, Q = 0.5 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local u = 0.1 * gain * samples[i]
		-- u = self.shelf.process(u)

		local u1, u2 = self.upsampler.tick(u)

		local y1, y2
		y1, self.s1, self.s2 = forward(self.u_prev, u1, self.s1, self.s2)
		y2, self.s1, self.s2 = forward(u1, u2, self.s1, self.s2)

		self.u_prev = u2

		local out = self.downsampler.tick(y1, y2)
		out = self.shelf.process(out)

		out = self.high.process(2 * out / gain)

		samples[i] = out
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
