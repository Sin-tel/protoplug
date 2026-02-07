--[[
tapped delay decorrelators
]]

require("include/protoplug")
local Line = require("include/dsp/delay_line")

local tapl = {
	1,
	56,
	153,
	208,
	304,
	340,
	471,
	534,
	652,
	672,
	788,
	870,
	941,
	1038,
	1121,
	1211,
	1273,
}
local ampl = {
	0.6685939871436434,
	0.3041464881286089,
	0.49173819383058626,
	-0.39259884113992555,
	-0.1975591837054567,
	0.37088877707980356,
	-0.15314793721429182,
	0.13352510745472046,
	0.2921647634195635,
	-0.31129095803570106,
	0.16931869913877018,
	-0.07451411440687547,
	-0.06516195399586215,
	0.1283192043452425,
	-0.07000400566674485,
	0.07558590065562402,
	-0.03665313896377769,
}
local tapr = {
	1,
	56,
	111,
	222,
	342,
	343,
	487,
	536,
	638,
	706,
	817,
	880,
	915,
	1040,
	1122,
	1195,
	1285,
}
local ampr = {
	0.5376947384661126,
	0.7327980015029444,
	-0.4567465079573343,
	-0.18329545567565675,
	-0.24998858478628377,
	0.17015721190682898,
	-0.14070600571799824,
	0.10597842321334652,
	-0.16476813838576398,
	0.07889685435849891,
	-0.1032636160626812,
	0.0590043474514812,
	-0.08254366136821031,
	-0.06121773123450625,
	0.038247555405490644,
	0.033661182707771194,
	-0.02947433750742254,
}

local tmult = 1.0

local pre_t = 50
local balance = 1

--- init
local line_l = Line(4000)
local line_r = Line(4000)

local pre_l = Line(4000)
local pre_r = Line(4000)

function plugin.processBlock(samples, smax)
	for i = 0, smax do
		local input_l = samples[0][i]
		local input_r = samples[1][i]

		local sl = 0
		local sr = 0

		for j in ipairs(tapl) do
			sl = sl + line_l.goBack_int(tapl[j] * tmult) * ampl[j]
			sr = sr + line_r.goBack_int(tapr[j] * tmult) * ampr[j]
		end

		local pl = pre_l.goBack_int(pre_t)
		local pr = pre_r.goBack_int(pre_t)

		line_l.push(pl)
		line_r.push(pr)

		pre_l.push(input_l)
		pre_r.push(input_r)

		samples[0][i] = input_l * (1.0 - balance) + sl * balance
		samples[1][i] = input_r * (1.0 - balance) + sr * balance
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
		name = "PreDelay",
		min = 0,
		max = 60,

		changed = function(val)
			pre_t = 1 + val * 44100 / 1000
			print(pre_t)
		end,
	},
	{
		name = "Time",
		min = 0.1,
		max = 2,
		changed = function(val)
			tmult = val
		end,
	},
})
