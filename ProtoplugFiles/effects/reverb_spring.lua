require("include/protoplug")
local Filter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/fdelay_line")

local function Allpass()
	local a1, a2 = 0, 0
	local x1, x2 = 0, 0
	local y0, y1, y2 = 0, 0, 0

	local public = {
		update = function(w, r)
			a1 = -2 * r * math.cos(w)
			a2 = r * r
		end,
		process = function(x0)
			y2, y1 = y1, y0
			y0 = a2 * x0 + a1 * x1 + x2 - a1 * y1 - a2 * y2
			x2, x1 = x1, x0
			return y0
		end,
	}

	return public
end

-- stylua: ignore start
local r = { 0.9778146660842164, 0.9707840674734362, 0.9675953465189503, 0.9670167159810779, 0.968934768848393, 0.9720915980736872, 0.9753317296217364, 0.9782169151449844, 0.9806339087400986, 0.9825791756149882, 0.9841970606270333, 0.985485925724752, 0.9866289074965284, 0.9875516363778913, 0.9883643542534913, 0.9890667870515265, 0.9896957040786643, 0.9902139369331093, 0.9906583531253733, 0.991140029706321, 0.9914736356571212, 0.9918444409643161, 0.9921411852977002, 0.9924751290414912, 0.9926978207865181, 0.9929576911125694, 0.9931804913641944, 0.9933661965055953, 0.9935890885999318, 0.9937748702878292, 0.9939235206951162, 0.9940721933773659, 0.9942580655585216, 0.9943696055772735, 0.9945183450995269, 0.9946299143653627, 0.9947786928874476, 0.9948530905065446, 0.994964697383922, 0.9950763168003659, 0.9951879487567732, 0.9952623770284232, 0.995336810874079, 0.9954484720948013, 0.9955229198771615, 0.9955973732346555, 0.9956718321675688, 0.9957462966763627 }
local w = { 0.009424872209491474, 0.031306283855860845, 0.057601677320342055, 0.08553071530113512, 0.11287855282900955, 0.13802725350800263, 0.1604113250055449, 0.18015643228442954, 0.19762386211268707, 0.21322202561939546, 0.22729650145223607, 0.24013003577749362, 0.25192683415970707, 0.262843977802368, 0.27302283978861885, 0.28255766884055444, 0.29152700555992045, 0.30000939054846276, 0.30808336440792716, 0.3157646352586627, 0.3231003274617169, 0.3301375653781372, 0.33689205712827275, 0.3433795108324727, 0.34963134273143537, 0.35567896906585905, 0.3615223898357438, 0.3671930212817879, 0.3726908634039912, 0.37801591620235386, 0.3831995959175742, 0.3882576106700013, 0.39317425233928605, 0.39796522904577747, 0.4026462489098249, 0.4072173119314283, 0.4116784181105876, 0.416045275567652, 0.42033359242297064, 0.4245276605561943, 0.4286274799673231, 0.4326487587767061, 0.43660720510469253, 0.44048711083093317, 0.4442884759554281, 0.4480270085985264, 0.45170270876022806, 0.4553155764405331 }
-- stylua: ignore end

local n = #w
print(n)

local feedback = 0.9
local balance = 1.0

local size = 1
local t_60 = 1.0

local ap = {}
for i = 1, n do
	-- print()
	ap[i] = Allpass()
	ap[i].update(w[i], r[i])
end

local delay1 = Line(8000)
local delay2 = Line(6000)

local k_ap = 0.625

local function allpass(s, apd, apl)
	local d = apd.goBack_int(apl)
	local v = s - k_ap * d
	apd.push(v)
	return k_ap * v + d
end

local shelf1 = Filter({
	type = "hs",
	f = 1000,
	gain = -3,
	Q = 0.7,
})

local lp1 = Filter({
	type = "lp",
	f = 2500,
	Q = 0.5,
})

local lp2 = Filter({
	type = "lp",
	f = 2500,
	Q = 1.30,
})

local apd1 = Line(327)
local apd2 = Line(283)

local apd1_l = 142
local apd2_l = 107

function plugin.processBlock(samples, smax)
	for k = 0, smax do
		local input_l = samples[0][k]
		local input_r = samples[1][k]

		local s_in = 0.5 * (input_l + input_r)

		local s1 = delay1.goBack(size * 4000)
		local s2 = delay2.goBack(size * 4000)

		s1 = lp1.process(s1)
		s1 = lp2.process(s1)

		for i = 1, n do
			s1 = ap[i].process(s1)
		end

		s1 = allpass(s1, apd1, apd1_l)

		s2 = shelf1.process(s2)
		s2 = allpass(s2, apd2, apd2_l)

		delay1.push(s2 * feedback + s_in)
		delay2.push(s1)

		samples[0][k] = input_l * (1.0 - balance) + s1 * balance
		samples[1][k] = input_r * (1.0 - balance) + s2 * balance
	end
end

local function setFeedback(t)
	if t then
		t_60 = t
	end
	if t_60 > 15 then
		feedback = 1.0
	else
		feedback = 10 ^ (-(60 * 4000 * size) / (t_60 * 44100 * 20))
	end
end

params = plugin.manageParams({
	{
		name = "Balance",
		min = 0,
		max = 1,
		default = 0.24,
		changed = function(val)
			balance = val
		end,
	},
	{
		name = "Length",
		min = 0.1,
		max = 1.00,
		default = 0.3,
		changed = function(val)
			size = val
			setFeedback()
		end,
	},
	{
		name = "Decay Time",
		min = 0.0,
		max = 1.0,
		default = 0.33,
		changed = function(val)
			setFeedback(2 ^ (8 * val - 4))
		end,
	},
	{
		name = "Diffusion",
		min = 0.0,
		max = 0.625,
		default = 0.15,
		changed = function(val)
			k_ap = val
		end,
	},
})
params.resetToDefaults()
