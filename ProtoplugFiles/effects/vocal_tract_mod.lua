require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

-- stylua: ignore
local diam_w0 = {
	0.53      , 0.48464286, 0.53214286, 0.8175    , 1.01857143,
       0.98964286, 0.99857143, 1.0525    , 1.08285714, 1.09821429,
       1.13071429, 1.17678571, 1.19      , 1.19      , 1.2       ,
       1.17928571, 1.16571429, 1.22857143, 1.35785714, 1.48607143,
       1.62428571, 1.77      , 1.86928571, 1.91357143, 1.84      ,
       1.635     , 1.43857143, 1.27357143, 1.13
}

-- stylua: ignore
local diam_phi1 = {
	 0.003     , -0.01742857, -0.03364286, -0.04807143, -0.06371429,
       -0.08214286, -0.103     , -0.123     , -0.14028571, -0.14928571,
       -0.14785714, -0.13417857, -0.10657143, -0.06796429, -0.019     ,
        0.03528571,  0.09      ,  0.14110714,  0.18307143,  0.21314286,
        0.22657143,  0.22325   ,  0.20164286,  0.16764286,  0.12514286,
        0.08317857,  0.04942857,  0.03414286,  0.041
}

-- stylua: ignore
local diam_phi2 = {
	 0.002     , -0.03046429, -0.06714286, -0.08685714, -0.08928571,
       -0.07821429, -0.05978571, -0.03675   , -0.00985714,  0.01860714,
        0.0505    ,  0.08364286,  0.118     ,  0.14832143,  0.169     ,
        0.17589286,  0.16557143,  0.137     ,  0.08885714,  0.02714286,
       -0.04042857, -0.10075   , -0.13971429, -0.13753571, -0.09171429,
        0.00882143,  0.1425    ,  0.26532143,  0.306
}

local c_len = #diam_w0

stereoFx.init()

local phi_1 = 0
local phi_2 = 0

local refl_0 = 0.75
local refl_l = -0.85

local con_x = 24
local con_a = 0.9
local con_s = 0.22

function stereoFx.Channel:init()
	print(c_len)
	self.wr = {}
	self.wl = {}
	self.junction_r = {}
	self.junction_l = {}
	self.area = {}
	for i = 1, c_len + 1 do
		self.wr[i] = 0
		self.wl[i] = 0
		self.junction_r[i] = 0
		self.junction_l[i] = 0
		self.area[i] = diam_w0[i]
	end

	self.l_i = 0

	self.lip_filter = Filter({ type = "hs", f = 5000, gain = -24, Q = 0.7 })

	self.turb_filter = Filter({ type = "bp", f = 800, Q = 1.0 })
end

function stereoFx.Channel:process_tract(s)
	-- glottis reflection
	local s_refl = s + refl_0 * self.wl[1]
	-- local t_noise = self.turb_filter.process((math.random() - 0.5) * s_refl)
	-- t_noise = 1 * t_noise * con_a ^ 3
	-- self.junction_r[1] = s_refl + t_noise
	self.junction_r[1] = s_refl

	-- lip reflection
	local k_out = self.wr[c_len]
	local lip_refl = refl_l * self.lip_filter.process(k_out)
	self.junction_l[c_len + 1] = lip_refl

	-- turbulence

	-- for j = 1, c_len do
	-- 	local a = self.area[j]
	-- 	local r = self.wr[j]
	-- 	local l = self.wl[j]

	-- 	if a > 1e-6 then
	-- 		local flow = math.abs(r - l) / a
	-- 		local turb = math.min(math.max((flow - 4) * 0.05, 0), 1)
	-- 		turb = turb * 0.05

	-- 		local noise = math.random() - 0.5
	-- 		self.wr[j] = self.wr[j] * (1.0 - turb) + noise * turb
	-- 		self.wl[j] = self.wl[j] * (1.0 - turb) + noise * turb
	-- 	end
	-- end

	-- KL reflections for all junctions
	for j = 2, c_len do
		local a1 = self.area[j - 1]
		local a2 = self.area[j]
		local sum = a1 + a2
		local k = 1.0
		if sum > 1e-6 then
			k = (a1 - a2) / sum
		end

		local w = k * (self.wr[j - 1] + self.wl[j])

		self.junction_r[j] = self.wr[j - 1] - w
		self.junction_l[j] = self.wl[j] + w
	end

	-- update
	for j = 1, c_len do
		self.wr[j] = self.junction_r[j] * 0.999
		self.wl[j] = self.junction_l[j + 1] * 0.999
	end

	local out = self.wr[c_len]
	-- local out = k_out - lip_refl
	return out
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		for j = 1, c_len do
			-- local a = (1.0 - l_set) * diam_a[j] + l_set * diam_i[j]
			local a = diam_w0[j] + phi_1 * diam_phi1[j] + phi_2 * diam_phi2[j]
			a = a * (1.0 - con_a * math.exp(-con_s * (j - c_len * con_x) ^ 2))

			a = math.max(0, a)

			self.area[j] = self.area[j] + (a * a - self.area[j]) * 0.001
		end

		-- run at double sample rate with zero stuffing
		local out1 = self:process_tract(s)
		local out2 = self:process_tract(0)

		local out = 0.5 * (out1 + out2)

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "phi1",
		min = -5,
		max = 5,
		default = 0,
		changed = function(val)
			phi_1 = val
		end,
	},
	{
		name = "phi2",
		min = -2.5,
		max = 2.2,
		default = 0,
		changed = function(val)
			phi_2 = val
		end,
	},

	{
		name = "constriction pos",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			con_x = val
		end,
	},
	{
		name = "constriction depth",
		min = 0,
		max = 1.3,
		default = 0,
		changed = function(val)
			con_a = val
		end,
	},
	{
		name = "constriction width",
		min = 1,
		max = 30,
		default = 0,
		changed = function(val)
			con_s = 1 / val
		end,
	},
})
