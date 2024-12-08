require("include/protoplug")
local Filter = require("include/dsp/cookbook_svf")

local diam = {}

-- stylua: ignore
diam.a = {
	0.43471226, 0.246392  , 0.29620854, 0.64893091, 0.6166486 ,
       0.4227582 , 0.59343651, 0.74091299, 0.87153654, 1.0122215 ,
       0.8900332 , 0.6361812 , 0.49146929, 0.55570968, 0.81968488,
       1.141694  , 1.51496167, 1.87162893, 2.06195209, 2.15822819,
       2.33627262, 2.5948679 , 2.79308724, 2.95887456, 2.99832804,
       2.80245116, 2.47232174, 2.14280414, 1.93176379
}

-- stylua: ignore
diam.e = {
	0.39803548, 0.36798514, 0.32582277, 0.35025426, 0.39421997,
       0.51085844, 0.7411445 , 0.91167944, 0.96523909, 0.92193748,
       0.78004613, 0.57549308, 0.39264889, 0.31688398, 0.36996547,
       0.49124593, 0.60052794, 0.62269113, 0.55995312, 0.50683257,
       0.55690222, 0.6784377 , 0.79877982, 0.9492375 , 1.15392569,
       1.36427743, 1.5315924 , 1.60439391, 1.57128577
}

-- stylua: ignore
diam.i = {
	0.33809303, 0.31276445, 0.38486365, 0.58009612, 0.67196616,
       0.60517035, 0.54015508, 0.56689116, 0.68929839, 0.77097427,
       0.70972427, 0.55772194, 0.43672582, 0.40065381, 0.37239502,
       0.29180284, 0.22428954, 0.24060933, 0.30529878, 0.32907974,
       0.30930958, 0.27440689, 0.26732588, 0.3723626 , 0.58745398,
       0.82405703, 1.02051156, 1.09852836, 1.04611184
}

-- stylua: ignore
diam.o = {
	0.42294459, 0.40216451, 0.45621359, 0.55784684, 0.55600793,
       0.4959005 , 0.52434412, 0.58457794, 0.57706638, 0.48031029,
       0.34915103, 0.25445734, 0.25153553, 0.40860688, 0.69914782,
       0.95041396, 1.04460955, 1.05735943, 1.13173461, 1.2769467 ,
       1.40644294, 1.45268236, 1.42272371, 1.3939646 , 1.3425452 ,
       1.19938816, 1.00323996, 0.84198894, 0.77481632
}

-- stylua: ignore
diam.u = {
	0.3970807 , 0.38492572, 0.42527727, 0.55053742, 0.60647431,
       0.56857593, 0.54778548, 0.51934318, 0.47121954, 0.40951611,
       0.33723652, 0.27581298, 0.21550431, 0.16552856, 0.1757332 ,
       0.23760953, 0.2862865 , 0.31531914, 0.35593098, 0.40430124,
       0.46847386, 0.53787343, 0.58572185, 0.62056103, 0.64294902,
       0.62279571, 0.58949604, 0.54777012, 0.49975392
}

stereoFx.init()

local c_len = #diam.a

local l_set = 0
local set1 = "u"
local set2 = "i"

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
		self.area[i] = diam.a[i]
	end

	self.l_i = 0

	self.lip_filter = Filter({ type = "hs", f = 5000, gain = -16, Q = 0.5 })
end

function stereoFx.Channel:process_tract(s)
	-- glottis reflection
	self.junction_r[1] = s + refl_0 * self.wl[1]

	-- lip reflection
	self.junction_l[c_len + 1] = refl_l * self.lip_filter.process(self.wr[c_len])

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
	return out
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		for j = 1, c_len do
			local a = (1.0 - l_set) * diam[set1][j] + l_set * diam[set2][j]
			-- a = a * (1.0 - con_a * math.exp(-con_s * (j - c_len * con_x) ^ 2))

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
		name = "a - i",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			l_set = val
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
