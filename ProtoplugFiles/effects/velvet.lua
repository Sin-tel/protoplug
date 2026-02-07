require("include/protoplug")
local Line = require("include/dsp/delay_line")

local tapl = {
	1,
	178,
	355,
	936,
	1386,
	1708,
	2051,
	2219,
	2725,
	3126,
	3404,
	3880,
	4092,
	4302,
	4906,
	5114,
}
local ampl = {
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

local tapr = {
	1,
	254,
	507,
	1054,
	1095,
	1674,
	1772,
	2387,
	2689,
	2879,
	3205,
	3658,
	4053,
	4298,
	4919,
	5130,
}
local ampr = {
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

local balance = 1
local tmult = 1
local tmult_ = 1

local line_l = Line(16000)
local line_r = Line(16000)

function plugin.processBlock(samples, smax)
	for k = 0, smax do
		tmult = tmult + (tmult_ - tmult) * 0.001
		local input_l = samples[0][k]
		local input_r = samples[1][k]

		local sl = 0
		local sr = 0

		line_l.push(input_l)
		line_r.push(input_r)
		for i in ipairs(tapl) do
			sl = sl + line_l.goBack_int((tapl[i] - 1) * tmult + 1) * ampl[i]
			sr = sr + line_r.goBack_int((tapr[i] - 1) * tmult + 1) * ampr[i]
		end

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
		min = 0.25,
		max = 2,
		changed = function(val)
			tmult_ = val
		end,
	},
})
