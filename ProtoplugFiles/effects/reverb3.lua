--[[
stereo reverb with early reflection section
]]

require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")
local Line = require("include/dsp/delay_line")

-- stylua: ignore start
tapl = {
    1, 150, 353, 
    546, 661, 683, 
    688, 1144, 1770, 
    2359, 2387, 2441, 
    2469, 2662, 2705, 
    3057, 3084, 3241, 
    3413, 3610, 
}
ampl = {
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
tapr = {
1, 21, 793, 
967, 1159, 1202, 
1742, 1862, 2069, 
2164, 2471, 2473, 
3126, 3272, 3328, 
3352, 3459, 3622, 
3666, 3789, 
}
ampr = {
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

local l1 = 2687
local l2 = 4349
local l3 = 5227
local l4 = 7547

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

local lfot = 0

-- absorption filters
local shelf1 = cbFilter({
    type = "hs",
    f = 2000,
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

        local gain = feedback
        
        -- orthogonal matrix
        -- stylua: ignore start
        local s1 = shelf1.process(sl + (-0.91769818*d1 + 0.07403183*d2 + 0.14636810*d3 + 0.36183660*d4) * gain)
        local s2 = shelf2.process(sr + ( 0.05567368*d1 - 0.38755436*d2 + 0.90835474*d3 - 0.14694802*d4) * gain)
        local s3 =               (sl + ( 0.35011072*d1 + 0.60836608*d2 + 0.33940563*d3 + 0.62619247*d4) * gain)
        local s4 =               (sr + ( 0.17931253*d1 - 0.68863025*d2 - 0.19563193*d3 + 0.67480630*d4) * gain)
        -- stylua: ignore end

        -- update delay lines
        pre_l.push(input_l)
        pre_r.push(input_r)

        pl = pre_l.goBack_int(pre_t)
        pr = pre_r.goBack_int(pre_t)

        line_l.push(pl)
        line_r.push(pr)

        line1.push(s1)
        line2.push(s2)
        line3.push(s3)
        line4.push(s4)

        -- output
        sl = sl * (1.0 - latebalance) + 0.5 * (d1 + d3) * latebalance
        sr = sr * (1.0 - latebalance) + 0.5 * (d2 + d4) * latebalance

        samples[0][i] = input_l * (1.0 - balance) + sl * balance
        samples[1][i] = input_r * (1.0 - balance) + sr * balance
    end
end

function setFeedback(t)
    if t then
        t_60 = t
    end
    print(t_60)
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
    --[[ {
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
