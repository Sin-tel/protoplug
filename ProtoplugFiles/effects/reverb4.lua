--[[
stereo reverb with early reflection section
]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/delay_line")

-- these are the early reflection coefficients
-- optimized by a python script to have minimal coloration

-- stylua: ignore start
local tapl = {
    1, 150, 353,
    546, 661, 683,
    688, 1144, 1770,
    2359, 2387, 2441,
    2469, 2662, 2705,
    3057, 3084, 3241,
    3413, 3610,
}
local ampl = {
0.6579562483759885, 0.24916228159437137,
-0.5122038920577012, 0.36330673539935077,
-0.4333746605125533, -0.4577140871718608,
0.49781845692600857, -0.18939379696133735,
-0.2742675178348754, -0.026542803499400146,
0.14192882965401657, -0.13860435085891593,
0.0465555003986965, -0.044959474245282856,
-0.14768870058256517, -0.08116161585856699,
-0.046801445561742955, -0.0979962170313839,
-0.04455145315483788, 0.08921755954681033,
}
local tapr = {
1, 21, 793,
967, 1159, 1202,
1742, 1862, 2069,
2164, 2471, 2473,
3126, 3272, 3328,
3352, 3459, 3622,
3666, 3789,
}
local ampr = {
0.29755424362094174, 0.9032103522197956, 
0.30566236871633573, -0.14208683332676209, 
0.13793374915217088, 0.1019480721591429, 
-0.20205322951447593, 0.10501607467781215, 
0.23692289191968258, 0.0501838324018514, 
0.07338616539393834, 0.09096667690763441, 
-0.1218410929057997, 0.07558917751391205, 
0.12901113392801317, 0.07933521679736777, 
-0.08103780888639031, 0.041229283316782016, 
-0.07247541530737873, 0.07164683067383586, 
}
-- stylua: ignore end

local balance = 1.0

local tmult = 1.0

local pre_t = 50

local kap = 0.5 -- 0.625

local l1 = 1297
local l2 = 1453
local l3 = 3187
local l4 = 3001
local l5 = 7109
local l6 = 7307
local l7 = 461
local l8 = 587

local feedback = 0.4

local time = 1.0
local time_ = 1.0
local t_60 = 1.0

local latebalance = 0.5

--- init
local line_l = Line(4000)
local line_r = Line(4000)

local pre_l = Line(4000)
local pre_r = Line(4000)

local line1 = Line(8000)
local line2 = Line(8000)
local line3 = Line(8000)
local line4 = Line(8000)
local line5 = Line(8000)
local line6 = Line(8000)
local line7 = Line(8000)
local line8 = Line(8000)

local lfot = 0

-- absorption filters
local shelf1 = cbFilter({
    type = "ls",
    f = 200,
    gain = -3,
    Q = 0.7,
})

local shelf2 = cbFilter({
    type = "ls",
    f = 200,
    gain = -3,
    Q = 0.7,
})

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        -- timing etc
        lfot = lfot + 1 / 44100

        local mod = 1.0 + 0.005 * math.sin(5.35 * lfot)
        local mod2 = 1.0 + 0.008 * math.sin(3.12 * lfot)

        time_ = time_ - (time_ - time) * 0.001

        --input

        local input_l = samples[0][i]
        local input_r = samples[1][i]

        local sl = 0
        local sr = 0

        -- get early reflections
        for i, v in ipairs(tapl) do
            sl = sl + line_l.goBack_int(tapl[i] * time_) * ampl[i]
            sr = sr + line_r.goBack_int(tapr[i] * time_) * ampr[i]
        end

        -- FDN network
        local d1 = line1.goBack(l1 * time_)
        local d2 = line2.goBack(l2 * time_)
        local d3 = line3.goBack(l3 * time_ * mod)
        local d4 = line4.goBack(l4 * time_ * mod2)
        local d5 = line5.goBack(l5 * time_)
        local d6 = line6.goBack(l6 * time_)
        local d7 = line7.goBack(l7 * time_)
        local d8 = line8.goBack(l8 * time_)

        local gain = feedback * 1

        -- randomly generated orthogonal matrix
        -- stylua: ignore start
        local s1 = shelf1.process(sl + (-0.38154601*d1 +0.628773*d2   -0.10215126*d3 -0.30873564*d4 +0.29937741*d5 +0.12424767*d6  -0.49660452*d7 +0.04042556*d8) * gain)
        local s2 = shelf2.process(sr + (-0.2584172*d1  -0.55174203*d2 -0.06248554*d3 +0.37784024*d4 +0.57404789*d5 -0.03341235*d6  -0.3874204*d7  -0.0373049*d8) * gain)
        local s3 =               (sl + (0.17616566*d1 -0.01007151*d2 -0.04866929*d3 -0.35528839*d4 +0.52151794*d5 +0.13894576*d6  +0.38018032*d7 -0.63595732*d8) * gain)
        local s4 =               (sr + (0.12975732*d1 +0.03687724*d2 -0.76552876*d3 +0.09895528*d4 +0.17093164*d5 +0.34177725*d6  +0.26503808*d7 +0.41194924*d8) * gain)
        local s5 =               (sl + (0.05112898*d1 -0.29865626*d2 -0.01737311*d3 -0.66020401*d4 +0.18506261*d5 -0.48593184*d6  +0.02308613*d7 +0.44845091*d8) * gain)
        local s6 =               (sr + (-0.46884187*d1 +0.2952903*d2  +0.11892298*d3 +0.31459522*d4 +0.24989798*d5 -0.41323626*d6  +0.57250508*d7 +0.13748759*d8) * gain)
        local s7 =               (sl + (0.32402592*d1 +0.20785793*d2 -0.46688196*d3 +0.19598948*d4 -0.05089573*d5 -0.66318809*d6  -0.23372278*d7 -0.31365027*d8) * gain)
        local s8 =               (sr + (-0.64214657*d1 -0.28136637*d2 -0.40599807*d3 -0.22944654*d4 -0.42468347*d5 -0.0248217*d6   +0.07473791*d7 -0.32317593*d8) * gain)
        -- stylua: ignore end

        -- update delay lines
        pre_l.push(input_l)
        pre_r.push(input_r)

        local pl = pre_l.goBack_int(pre_t)
        local pr = pre_r.goBack_int(pre_t)

        line_l.push(pl)
        line_r.push(pr)

        line1.push(s1)
        line2.push(s2)
        line3.push(s3)
        line4.push(s4)
        line5.push(s5)
        line6.push(s6)
        line7.push(s7)
        line8.push(s8)

        -- output
        sl = sl * (1.0 - latebalance) + 0.5 * (d1 + d2 + d3 + d4 + d5 + d6 + d7 + d8) * latebalance
        sr = sr * (1.0 - latebalance) + 0.5 * (d1 - d2 + d3 - d4 + d5 - d6 + d7 - d8) * latebalance

        samples[0][i] = input_l * (1.0 - balance) + sl * balance
        samples[1][i] = input_r * (1.0 - balance) + sr * balance
    end
end

local function setFeedback(t)
    if t then
        t_60 = t
    end
    --print(t_60)
    if t_60 > 15 then
        feedback = 1.0
    else
        feedback = 10 ^ (-(60 * 4000 * time) / (t_60 * 44100 * 20))
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
        name = "Balance",
        min = 0,
        max = 1,
        changed = function(val)
            latebalance = val
        end,
    },
    {
        name = "PreDelay",
        min = 0,
        max = 60,

        changed = function(val)
            pre_t = 1 + val * 44100 / 1000
        end,
    },
    --[[{
        name = "Early Size";
        min = 0.1;
        max = 1;
        changed = function(val) tmult = val end;
    };]]
    {
        name = "Size",
        min = 0.3,
        max = 1,
        changed = function(val)
            time = val
            setFeedback()
        end,
    },
    {
        name = "Decay Time",
        min = 0,
        max = 1,
        changed = function(val)
            setFeedback(2 ^ (8 * val - 4))
        end,
    },
})
