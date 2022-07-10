require("include/protoplug")

a = 4

function plugin.processBlock(s, smax)
    for i = 0, smax do
        s[0][i] = math.exp(-a) * math.tan(math.pi * (math.random() - 0.5))
        s[1][i] = math.exp(-a) * math.tan(math.pi * (math.random() - 0.5))

        --[[local u1 = math.random()
        local u2 = math.random()
        local r = math.sqrt(-2*math.log(u1))
        local th = math.cos(2*math.pi*u2)
        s[0][i] = math.exp(-a)*r*math.cos(th)
        s[1][i] = math.exp(-a)*r*math.sin(th)]]
    end
end

params = plugin.manageParams({
    {
        name = "Drive",
        min = 0,
        max = 12,
        default = 0,
        changed = function(val)
            a = val
        end,
    },
})
