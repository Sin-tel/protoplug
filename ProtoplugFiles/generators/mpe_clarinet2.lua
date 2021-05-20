--[[
 ok this one actually sounds like a clarinet
]]

require "include/protoplug"

local Line = require "include/dsp/delay_line"
local cbFilter = require "include/dsp/cookbook filters"


local attack = 0.005
local release = 0.005
local kappa = 0
local split = 0.8
local mod = 0
local register = 0

local tun_m = 1
local tun_o = 0

polyGen.initTracks(8)

pedal = false

TWOPI = 2*math.pi

local freq = 4.5*TWOPI/44100



function newChannel()
    new = {}
    
    new.pressure = 0
    
    new.phase = 0
	new.f = 0
	new.pitch = 0
	new.pitchbend = 0
	new.vel = 0
    new.slide = 0
	
	return new
end

channels = {}

for i = 1,16  do
    channels[i] = newChannel()
end

function setPitch(ch)
    ch.f = getFreq(ch.pitch + ch.pitchbend)
end

function polyGen.VTrack:init()
	self.channel = 0
	
	self.f_ = 0
	self.pres_ = 0
	self.phase = 0
	
	self.fv = 0
	
	self.delayline = Line(1024)
	
	self.reg = 0
	self.reg2 = 0

	
	self.lp = cbFilter
	{
		type 	= "lp";
		f 		= 7000;
		gain 	= 0;
		Q 		= 0.7;
	}
	
	self.lp2 = cbFilter
	{
		type 	= "lp";
		f 		= 2000;
		gain 	= 0;
		Q 		= 0.7;
	}
	
	self.reedfilter = cbFilter
	{
		type 	= "lp";
		f 		= 900;
		gain 	= 0;
		Q 		= 0.9;
	}
	
	self.dcblock = cbFilter
	{
		type 	= "hp";
		f 		= 50;
		gain 	= 0;
		Q 		= 0.7;
	}
	self.noisefilter = cbFilter
	{
		-- initialize filters with current param values
		type 	= "bp";
		f 		= 900;
		gain 	= 0;
		Q 		= 1.0;
	}
end

function processMidi(msg)
    --print(msg:debug())
    local ch = msg:getChannel()
    if(msg:isPitchBend()) then
        local p = msg:getPitchBendValue ()
        if ch ~= 1 then
            p = (p - 8192)/8192
            local pitchbend = p*48
            
            local chn = channels[ch]
            chn.pitchbend = pitchbend
            setPitch(chn)
        end
    elseif msg:isControl() then
        --print(msg:getControlNumber())
    
        if msg:getControlNumber() == 64 then
            pedal = msg:getControlValue() ~= 0
        end
        
        if msg:getControlNumber() == 74 then
            local chn = channels[ch]
            chn.slide = (msg:getControlValue()-64)/64
        end
    elseif msg:isPressure() then
        if ch > 1 then
            local pr = msg:getPressure()/127
           -- pr = 1 - (1-pr)*(1-pr)
            channels[ch].pressure = pr
        end
    end
end

--function sign ( val ) return math.max ( math.min ( val * math.huge, 1 ), -1 ) end

function sign(n)
	return n < 0 and -1 or n > 0 and 1 or 0
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    local ch = channels[self.channel]
    
    if ch then
    
        local maxpres = 0
        
        for i =1,16 do
            local p = channels[i].pressure
            if p > maxpres then
                maxpres = p
                
            end    
        end
        
    
        for i = 0,smax do
        
            local a = attack
            if self.pres_ > ch.pressure then
                a = release
            end
            self.pres_ = self.pres_ - (self.pres_ - ch.pressure)*a
            
            self.f_ = self.f_ - (self.f_ - ch.f)*0.0002 
            
            
            
            --[[local fa = ch.f - self.f_
            self.fv = self.fv + freq*(fa - 0.4*self.fv)
            self.fv = math.tanh(self.fv*0.7/self.f_)*(self.f_/0.7)
            self.f_ = self.f_ + freq*self.fv]]
            
            self.phase = self.phase + freq 
            --self.phase = self.phase + (0.68*self.f_ * TWOPI)
            
            
            local nse = math.random()-0.5
            nse = self.noisefilter.process(nse)
            
            local len = 1/(self.f_*tun_m) + tun_o
            
            local len2 = 1/(3.2*self.f_*tun_m) + tun_o
            
            local b1 = self.delayline.goBack(len)
            
            b1 = self.lp.process(b1)
            
            local b2 = self.delayline.goBack(len2)
            
            b2 = self.lp2.process(b2)
            
            local r = self.reg*register
            
            local boreOut = (1.0 - r)*b1 + r*b2
            
            
            local boreOut = -0.85*boreOut
            
            
            
            
        
            local pressure = (1.0 + 0.2*nse + ch.slide*0.4*math.sin(self.phase))*self.pres_ --+ ch.slide*0.5*math.sin(self.phase)
            
            
            local presdiff = pressure - boreOut
            
            local reedx = (1 - presdiff)
            reedx = self.reedfilter.process(reedx)
            reedx = math.min(1,math.max(0,reedx))
            
            
            
            --local flow = reedx*sign(presdiff)*math.sqrt(math.abs(presdiff))
            local flow = reedx*math.tanh(1.7*presdiff)
            
            flow = flow --* (1.0 + 0.8*nse)
            
            
            
            
            self.delayline.push(boreOut + flow)

            
            
            local out = self.dcblock.process(boreOut)
            
           
		
            
            local samp = out
		
            samples[0][i] = samples[0][i] + samp*0.25 -- left
            samples[1][i] = samples[1][i] + samp*0.25 -- right
        end
        
     end
end

function polyGen.VTrack:noteOff(note, ev)
	local i = ev:getChannel()
    local ch = channels[i]
    --print(i, "off")
    ch.pressure = 0
    
    local maxpres = 0
    local maxi = 0
        
   --[[ for j =1,16 do
        local p = channels[j].pressure
        if p > maxpres then
            maxpres = p
            maxi = j
                
        end    
    end
    
    if maxpres > 0.01 then
        self.channel = maxi
        self.f_ = channels[maxi].f
        print(self.channel, "active")
    end]]
end

function polyGen.VTrack:noteOn(note, vel, ev)
    
    local i = ev:getChannel()
    --activech = i
    --print(i, "on")
    
    local assignNew = true
    for j=1,polyGen.VTrack.numTracks do
        local vt = polyGen.VTrack.tracks[j]
        if vt.channel == i then
            assignNew = false
        end
    end

    if assignNew then
        self.channel = i
    end
    
    local ch = channels[i]
    
    ch.pitch = note
    

    print(note)
    
    setPitch(ch)
    self.f_ = ch.f
    
    self.reedfilter.update({f = 900 + 44100*self.f_*4.2, Q = 0.9})
     
    -- 80
    if note > 68 then
        ch.pitch = note - 19.0195
        setPitch(ch)
        self.f_ = ch.f
        self.reg = 1.0
    else
        self.reg = 0.0
    end
    
    ch.pressure = 0
    
   
    

    
   -- self.pres_ = 0
end


function getFreq(note)
    local n = note - 69
	local f = 440 * 2^(n/12)
	return f/44100
end


params = plugin.manageParams {
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	{
		name = "Attack";
		min = 4;
		max = 10;
		default = 4.5;
		changed = function(val) attack = math.exp(-val) end;
	};
		{
		name = "Release";
		min = 4;
		max = 12;
		default = 7;
		changed = function(val) release = math.exp(-val) end;
	};
	{
		name = "Register";
		min = 0;
		max = 1;
		default = 0.21;
		changed = function(val) register = val end;
	};
	{
		name = "Tune master";
		min = -0.5;
		max = 0.5;
		default = 0.01;
		changed = function(val) tun_m = math.exp(val) end;
	};
	{
		name = "Tune offset";
		min = -10;
		max = 10;
		default = -1.6;
		changed = function(val) tun_o = val end;
	};
}

params.resetToDefaults()

