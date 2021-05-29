--[[
physical model of a piano
kind of terrible

]]


require "include/protoplug"

local Line = require "include/dsp/fdelay_line"
local cbFilter = require "include/dsp/cookbook filters"


local release = 0.99
local decay = 0.99

local position = 0.2

polyGen.initTracks(12)

local pitchbend = 0

local pedal = false

local tun_m = 1
local tun_o = 0


local dt = 0.001

function polyGen.VTrack:init()
	-- create per-track fields here
	
	self.f = 1
	self.pitch = 0
	self.vel = 0
	self.finished = true
	
	self.decay = 0.99
	
	self.delayL = Line(1024)
	self.delayR = Line(1024)
	self.delayL2 = Line(1024)
	self.delayR2 = Line(1024)
	self.delay_long = Line(1024)
	
	self.hammer_x = 0
	self.hammer_v = 0
	self.hammer_ef = 0 -- external force
	self.hammer_d = 0.1
	
	self.ap = cbFilter
	{
		-- initialize filters with current param values
		type 	= "ap";
		f 		= 5000;
		gain 	= 0;
		Q 		= 0.7;
	}
	
	self.lp = cbFilter
	{
		-- initialize filters with current param values
		type 	= "hs";
		f 		= 4000;
		gain 	= -2;
		Q 		= 0.7;
	}
	self.lp2 = cbFilter
	{
		-- initialize filters with current param values
		type 	= "hs";
		f 		= 4000;
		gain 	= -0.5;
		Q 		= 0.7;
	}
	
	self.lpl = cbFilter
	{
		-- initialize filters with current param values
		type 	= "lp";
		f 		= 9000;
		gain 	= 0;
		Q 		= 0.7;
	}
	
	self.noisefilter = cbFilter
	{
		-- initialize filters with current param values
		type 	= "lp";
		f 		= 500;
		gain 	= 0;
		Q 		= 0.7;
	}
end

function processMidi(msg)
    if(msg:isPitchBend()) then
        local p = msg:getPitchBendValue ()
        p = (p - 8192)/8192
        pitchbend = p*2
        for i=1,polyGen.VTrack.numTracks do
            local vt = polyGen.VTrack.tracks[i]
            vt.f = getFreq(vt.pitch+pitchbend)
        end
    elseif msg:isControl() then
        if msg:getControlNumber() == 64 then
            pedal = msg:getControlValue() ~= 0
        end
        print(pedal)
    end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
	for i = 0,smax do
	    
		local nse = math.random()-0.5
		
		nse = self.noisefilter.process(nse)
		
		local len = 1/(self.f*tun_m) + tun_o
		local len2 = len*0.9995
		
		local right = -self.delayR.goBack((1-position)*len )
        local left  = -self.delayL.goBack(   position*len )
        
        local right2 = -self.delayR2.goBack((1-position)*len2 )
        local left2  = -self.delayL2.goBack(   position*len2 )
        
        local long = -self.delay_long.goBack( len*0.1)
        
        long = self.lpl.process(long)
        
        --long = self.ap.process(long)
        
        --left = self.lp.process(left)
        --left2 = self.lp2.process(left2)
        
        local s = right + left + long + right2 + left2
        
        
        local hf = 0
        if s > self.hammer_x then
            local h = s - self.hammer_x
            
            local hv = (s - self.hammer_v)*dt
            
            local p = math.pow(h,2.5)
            
            
            
            hf = self.hammer_d*p*(1.0+0.5*hv) 
            
            hf = hf * (1.0 + 0.0*nse)
            
            hf = math.min(1,hf)
        end
        
        self.hammer_v = self.hammer_v + dt*(hf - 0.0*self.hammer_ef)
        self.hammer_x = self.hammer_x + self.hammer_v
        
        self.hammer_ef = self.hammer_ef*0.99 -- 0.99
		if self.hammer_ef < 0.01 then
			self.hammer_ef = 0
		end
		

    
        
        local d = self.decay
        if self.finished and not pedal then
            d = release
        end
        
        local a = self.decay
        local b = 1-a
        
        local l1 = a*left + b*left2
        local l2 = a*left2 + b*left
        
        
        self.delayL.push(right*d - hf)
        self.delayR.push(l1*d - hf)
        
        self.delayL2.push(right2*d - hf)
        self.delayR2.push(l2*d - hf)
		
		self.delay_long.push(long*d + 0.01*(right + right2) - hf)
		
		local out = left + right + 0.2*long + left2 + right2
		
		
		local sample = out*0.01 / math.sqrt(self.hammer_d)
		
		
		samples[0][i] = samples[0][i] + sample -- left
		samples[1][i] = samples[1][i] + sample -- right
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.finished = true
end

function polyGen.VTrack:noteOn(note, vel, ev)
    self.finished = false
  
    self.pitch = self.note
    self.f = getFreq(self.pitch+pitchbend)
    

    local v = vel/127
    --local v = 2^((vel-127)/30)
    
    v = v * 0.3
    
	self.vel = v

	
	self.hammer_x = 1
	self.hammer_v = -0.1*v
	self.hammer_ef = 5*v
	
	self.decay = math.pow(0.99,0.0004/self.f)

    self.hammer_d = 1.0-math.pow(0.9,0.02/self.f)
    
    print(self.hammer_d )
end

function getFreq(note)
    local n = note - 69
	local f = 440 * 2^(n/12)
	return f/44100
end

function getBellFreq(note)
    local n = note - 69
	local f = 1200 * 2^(n/34)
	return f/44100
end


params = plugin.manageParams {
    {
		name = "decay";
		min = 4;
		max = 12;
		default = 6.2;
		changed = function(val) decay = 1.0-math.exp(-val) end;
	};
	{
		name = "release";
		min = 2;
		max = 10;
		default = 3;
		changed = function(val) release = 1.0-math.exp(-val) end;
	};
	{
		name = "Position";
		min = 0;
		max = 0.5;
		default = 0.278;
		changed = function(val) position = val end;
	};
	{
		name = "Tune master";
		min = -0.5;
		max = 0.5;
		default = 0;
		changed = function(val) tun_m = math.exp(val) end;
	};
	{
		name = "Tune offset";
		min = -10;
		max = 10;
		default = -1.97;
		changed = function(val) tun_o = val end;
	};
}

params.resetToDefaults()