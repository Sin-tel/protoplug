--[[
shitty model of a clarinet
pretty much just a square wave
]]

require "include/protoplug"

local Line = require "include/dsp/delay_line"
local cbFilter = require "include/dsp/cookbook filters"


attack = 0.005
release = 0.005

polyGen.initTracks(1)

pedal = false

TWOPI = 2*math.pi

local freq = 6*TWOPI/44100



function newChannel()
    new = {}
    
    new.pressure = 0
    
    new.phase = 0
	new.f = 0
	new.pitch = 0
	new.pitchbend = 0
	new.vel = 0

	
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
	
	self.delayLine = Line(1024)
	
	self.lp = cbFilter
	{
		-- initialize filters with current param values
		type 	= "lp";
		f 		= 8000;
		gain 	= 0;
		Q 		= 0.7;
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
    elseif msg:isPressure() then
        if ch > 1 then
            local pr = msg:getPressure()/127
            pr = 1 - (1-pr)*(1-pr)
            channels[ch].pressure = pr
        end
    end
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
            self.pres_ = self.pres_ - (self.pres_ - maxpres)*a
            
            --self.f_ = self.f_ - (self.f_ - ch.f)*0.002 
            
            
            
            local fa = ch.f - self.f_
            self.fv = self.fv + freq*(fa - 0.4*self.fv)
            self.fv = math.tanh(self.fv*0.7/self.f_)*(self.f_/0.7)
            self.f_ = self.f_ + freq*self.fv
            
            --self.phase = self.phase + (self.f_*TWOPI)
            
            
            local nse = math.random()-0.5
            
            local boreOut = -0.95 * self.delayLine.goBack(1/self.f_ ) --filter
            
            
            boreOut = self.lp.process(boreOut)
            
        
            local pressure = (0.6 + 0.02*nse)*self.pres_
            
            
            local presdiff = boreOut - pressure  
            local refl = -1.2*presdiff + 0.3
            refl = math.tanh(refl)
            self.delayLine.push(pressure + presdiff*refl)
            
            
            local out = boreOut
            
           
		
            
            local samp = out
		
            samples[0][i] = samples[0][i] + samp*0.5 -- left
            samples[1][i] = samples[1][i] + samp*0.5 -- right
        end
        
     end
end

function polyGen.VTrack:noteOff(note, ev)
	local i = ev:getChannel()
    local ch = channels[i]
    print(i, "off")
    ch.pressure = 0
    
    local maxpres = 0
    local maxi = 0
        
    for j =1,16 do
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
    end
end

function polyGen.VTrack:noteOn(note, vel, ev)
    
    local i = ev:getChannel()
    --activech = i
    print(i, "on")
    
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
    
    ch.pressure = 0
    
    setPitch(ch)
    self.f_ = ch.f
    
    print(1/self.f_)
    
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
		default = 5;
		changed = function(val) attack = math.exp(-val) end;
	};
		{
		name = "Release";
		min = 4;
		max = 12;
		default = 5;
		changed = function(val) release = math.exp(-val) end;
	};
}
