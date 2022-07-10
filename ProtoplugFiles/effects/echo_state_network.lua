require("include/protoplug")


stereoFx.init()

size = 40

sparse = 0.5

w = {}
w_in = {}
w_out = {}
for i=1,size do
    w[i] = {}
    
    w_in[i] = i%2
    w_out[i] = (i+1)%2
    for j = 1,size do
        w[i][j] = 0
        if math.random() < sparse then
            w[i][j] = math.random() - 0.5
        end
    end
end



function stereoFx.Channel:init()
	self.arr = {}
	for i=1,size do
        self.arr[i] = 0
    end
end


function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

        local a_new = {}
		for i=1,size do
		    a_new[i] = w_in[i] * s * gain_in + bias
		    for j=1,size do
		        a_new[i] = a_new[i] + w[i][j] * self.arr[j] * gain
		    end
		end
		
		local out = 0
		for i=1,size do
		    local y = math.tanh(a_new[i])
		    self.arr[i] = self.arr[i]*(1-f) + f*y + 0.01 * (math.random()- 0.5)
		    out = out + w_out[i] * y
        end

		samples[i] = out
	end
end

params = plugin.manageParams({
	{
		name = "Gain_in",
		min = 0,
		max = 5,
		default = 1,
		changed = function(val)
			gain_in = val
		end,
	},
	{
		name = "Gain",
		min = 0,
		max = 5,
		default = 1,
		changed = function(val)
			gain = val
		end,
	},
	{
		name = "bias",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			bias = val
		end,
	},
	{
		name = "f",
		min = 0,
		max = 1,
		default = 0,
		changed = function(val)
			f = val
		end,
	},

	{
		name = "W",
		min = 0,
		max = 5,
		default = 1,
		changed = function(val)
			for i=1,size do
			    for j = 1,size do
                    w[i][j] = 0
                    if math.random() < sparse then
                        local idx = i + j * size + val
                        --w[i][j] = math.sin(idx*1.5)
                        w[i][j] = math.random() - 0.5
                    end
                end
			end
		end,
	},
})

--params.resetToDefaults()

