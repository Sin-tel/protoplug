
require("include/protoplug")
local cbFilter = require("include/dsp/cookbook filters")

local a = 0.0
local b = 0.0
local c = 0.0

stereoFx.init()
function stereoFx.Channel:init()
	self.rand = 0.1
	self.a0 = 0
	self.a1 = 0
	self.a2 = 0
	
	self.hp = cbFilter({ type = "hp", f = 20, gain = 0, Q = 0.7 })
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]
		
		self.rand = self.rand * 3.0
		self.rand = self.rand + ((self.rand > 2) and -1 or 0)
		self.rand = self.rand + ((self.rand > 1) and -1 or 0)
		
		local noise = self.rand * 2.0 - 1.0
		
		--local noise = math.random() * 2.0 - 1.0
		

		self.a0 = 0.99765 * self.a0 + noise * 0.0990460;
		self.a1 = 0.96300 * self.a1 + noise * 0.2965164;
		self.a2 = 0.57000 * self.a2 + noise * 1.0526913;
		noise = self.a0 + self.a1 + self.a2 + noise * 0.1848; 
		noise = noise * 0.2;
		
		--local out = math.abs(noise*noise)
		

		local out = (math.exp(3*noise * a) - 1.0)/(5*a+0.01)


		samples[i] = self.hp.process(out)
	end
end
params = plugin.manageParams {
	{
		name = "a";
		min = 0;
		max = 1;
		changed = function (val) a = val end;
	};
	{
		name = "b";
		min = 0;
		max = 1;
		changed = function (val) b = val end;
	};
	{
		name = "c";
		min = 0;
		max = 1;
		changed = function (val) c = val end;
	};
}
