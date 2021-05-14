require "include/protoplug"
FLine = require "include/dsp/fdelay_line"
local cbFilter = require "include/dsp/cookbook filters"

local maxLength = 3*44100
local fadeSpeed = 20/44100

local balance = 0.5

local lpfilters = {}
local hpfilters = {}

stereoFx.init()

function stereoFx.Channel:init()
    self.delayline = FLine(maxLength)
    self.length = 0
    self.ptr1 = 0
    self.ptr2 = 0
    self.a1 = 1.0
    self.a2 = 0.0
    self.fade = 1
    
    self.lp = cbFilter
	{
		-- initialize filters with current param values
		type 	= "lp";
		f 		= 12000;
		gain 	= 0;
		Q 		= 0.7;
	}
	table.insert(lpfilters, self.lp)
	self.hp = cbFilter
	{
		-- initialize filters with current param values
		type 	= "hp";
		f 		= 350;
		gain 	= 0;
		Q 		= 0.7;
	}
	table.insert(hpfilters, self.hp)
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0,smax do
	    self.length = self.length*0.999 + length*0.001
	    local l = self.length*44100
	    
	    self.ptr1 = self.ptr1 - (speed - 1)
	    self.ptr2 = self.ptr2 - (speed - 1)
	    
	    if self.fade == 1 then
	        self.a1 = math.min(1.0,self.a1+fadeSpeed)
	        self.a2 = math.max(0.0,self.a2-fadeSpeed)
	    else
	        self.a2 = math.min(1.0,self.a2+fadeSpeed)
	        self.a1 = math.max(0.0,self.a1-fadeSpeed)
	    end
	    
	    
	    if speed >= 1 then
	        if self.ptr1 < l*0.5 and self.fade == 1 then
                self.ptr2 = l*1.5
                self.fade = 2
            end 
            if self.ptr2 < l*0.5 and self.fade == 2 then
                self.ptr1 = l*1.5
                self.fade = 1
            end 
        else
            if self.ptr1 > l*1.5  and self.fade == 1 then
                self.ptr2 = l*0.5
                self.fade = 2
            end 
            if self.ptr2 > l*1.5  and self.fade == 2 then
                self.ptr1 = l*0.5
                self.fade = 1
            end 
        end
            
	    --self.ptr = self.ptr % maxLength
	    
	    
	    local s = samples[i]
	    local d = self.delayline.goBack(self.ptr1)*self.a1 + self.delayline.goBack(self.ptr2)*self.a2
	    
	    d = self.lp.process(d)
	    d = self.hp.process(d)
	    if (gain > 1) then
	        d = softclip(d*gain)/gain
	    end
	    
	    local signal = s+d*feedback
	    self.delayline.push(signal)
		samples[i] = s*(1.0-balance)+d*balance
	end
end

function softclip(x) 
    if x <= -1 then
        return -2.0/3.0
    elseif x >= 1 then
        return 2.0/3.0
    else
        return x - (x*x*x)/3.0
    end
end

local function updateFilters(filters,args)
	for _, f in pairs(filters) do
		f.update(args)
	end
end

params = plugin.manageParams {
	{
		name = "Length";
		max = 2;
		changed = function(val) length = val end;
	};
	{
		name = "Feedback";
		max = 1.2;
		changed = function(val) feedback = val end;
	};
	{
		name = "Speed";
		max = 3;
		min = -3;
		changed = function(val) speed = val end;
	};
	{
		name = "Distort";
		max = 4;
		min = 1;
		changed = function(val) gain = val end;
	};
	{
		name = "Dry/Wet";
		min = 0;
		max = 1;
		changed = function(val) balance = val end;
	};
	{
		name = "Highpass";
		min = 0;
		max = 1000;
		changed = function(val) updateFilters(hpfilters,{f=val}) end;
	};
	{
		name = "Lowpass";
		min = 5000;
		max = 22000;
		changed = function(val) updateFilters(lpfilters,{f=val}) end;
	};
}
