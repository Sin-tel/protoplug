require("include/protoplug")
local Line = require("include/dsp/delay_line")

local len1_l = { 1, 178, 355, 936, 1386, 1708, 2051, 2219, 2725, 3126, 3404, 3880, 4092, 4302, 4906, 5114 }
local amp_l = {
	0.4823646508710854,
	0.6697278566759453,
	-0.42255731357328447,
	-0.16075868611184735,
	0.13266746979192826,
	0.11500360642482889,
	0.29223542848643547,
	-0.2462863106377109,
	-0.07415398786977184,
	-0.12279021745256427,
	0.05522189028101822,
	-0.13350952978901676,
	0.12158317604353781,
	-0.11085732053353464,
	0.028568358924861363,
	-0.030072639740795406,
}
local len1_r = { 1, 254, 507, 1054, 1095, 1674, 1772, 2387, 2689, 2879, 3205, 3658, 4053, 4298, 4919, 5130 }
local amp_r = {
	0.5387382437717181,
	-0.7236127882579902,
	-0.3966217561992254,
	-0.17102938751197932,
	0.18526315716890968,
	-0.13042035786168707,
	0.1248243683158048,
	-0.23625538035093369,
	-0.12563055096031853,
	-0.2230102199561975,
	-0.20006062528914023,
	-0.16456714043098827,
	0.046402864272314624,
	-0.04154630673125082,
	0.03223917577180164,
	-0.04559372032137723,
}

local len2_l = { 60, 88, 276, 434, 632, 710, 727, 840, 861, 862, 915, 943, 1068, 1080, 1093, 1197 }
local sign_l = { 1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, -1.0, -1.0 }
local len2_r = { 2, 125, 272, 350, 374, 657, 725, 859, 904, 955, 985, 1050, 1071, 1092, 1101, 1134 }
local sign_r = { 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0 }

local n = 16

assert(#len1_l == n)
assert(#len1_r == n)
assert(#len2_l == n)
assert(#len2_r == n)

assert(#amp_l == n)
assert(#amp_r == n)

assert(#sign_l == n)
assert(#sign_r == n)

local balance = 1
local tmult = 1
local tmult_ = 1

local line_l = Line(16000)
local line_r = Line(16000)

local s = {}
for i = 1, n do
	s[i] = 0.
end

local max_l = 1600

local delays = {}
for i = 1, n do
	delays[i] = Line(max_l)
end

local mix_a = 0
local mix_b = 0

local u = {}
for i = 1, n do
	u[i] = 0.
end

local g = 1 / math.sqrt(n)
local function hadamard(x)
	for i = 1, n do
		u[i] = x[i]
	end

	local h = 1
	while h < n do
		for i = 1, n, h * 2 do
			for j = i, i + h - 1 do
				local a, b = u[j], u[j + h]
				u[j] = a + b
				u[j + h] = a - b
			end
		end
		h = h * 2
	end

	for i = 1, n do
		u[i] = u[i] * g
	end
	return u
end

function plugin.processBlock(samples, smax)
	for k = 0, smax do
		tmult = tmult + (tmult_ - tmult) * 0.001
		local tmul1 = 0.2 + 0.8 * tmult
		local tmul2 = 0.5 + 0.5 * tmult

		local input_l = samples[0][k]
		local input_r = samples[1][k]

		local sl = 0
		local sr = 0

		for i = 1, n do
			s[i] = 0.0
		end

		line_l.push(input_l)
		line_r.push(input_r)

		for i = 1, n do
			local l = line_l.goBack_int((len1_l[i] - 1) * tmul1 * 2 + 1) * amp_l[i]
			local r = line_r.goBack_int((len1_r[i] - 1) * tmul1 * 2 + 1) * amp_r[i]

			sl = sl + l
			sr = sr + r

			if i % 2 == 0 then
				s[i] = l
			else
				s[i] = r
			end
		end
		s = hadamard(s)

		local dl = 0
		local dr = 0
		for i = 1, n do
			delays[i].push(s[i])
			dl = dl + sign_l[i] * delays[i].goBack_int((len2_l[i] - 1) * tmul2 + 1)
			dr = dr + sign_r[i] * delays[i].goBack_int((len2_r[i] - 1) * tmul2 + 1)
		end

		sl = sl * mix_a + dl * mix_b
		sr = sr * mix_a + dr * mix_b

		samples[0][k] = input_l * (1.0 - balance) + sl * balance
		samples[1][k] = input_r * (1.0 - balance) + sr * balance
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
		name = "Time",
		min = 0,
		max = 1,
		changed = function(val)
			tmult_ = val
		end,
	},

	{
		name = "Diffusion",
		min = 0,
		max = 1,
		changed = function(val)
			mix_a = math.sqrt(1 - val)
			mix_b = math.sqrt(val)
		end,
	},
})
