require "include/protoplug"
local bit = require("bit")
local downsampler = require("include/dsp/downsampler")



local attack = 0.005
local release = 0.005

local oversample = 4
local samplerate = 44100*oversample

polyGen.initTracks(8)

pedal = false

local TWOPI = 2*math.pi

function newChannel()
    new = {}
    new.pressure = 0
    new.phase = 0
	new.pitch = 0
	new.pitchbend = 0
	new.vel = 0
	
	return new
end

channels = {}

for i = 1,16  do
    channels[i] = newChannel()
end

function polyGen.VTrack:init()
	self.channel = 0
	
	self.pitch = 0
	self.f = 0
	self.pres_ = 0
	
	self.phase = 0
	
	self.dsampler = downsampler()
    self.dsampler2 = downsampler()
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

        end
    elseif msg:isControl() then
    
        if msg:getControlNumber() == 64 then
            pedal = msg:getControlValue() ~= 0
        end
    elseif msg:isPressure() then
        if ch > 1 then
            channels[ch].pressure = msg:getPressure()/127
        end
    end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    local ch = channels[self.channel]
    
    --print(smax)
    local smax_ov = (smax+1)*oversample-1
    
    if ch then
        for i = 0,smax_ov do
            local a = attack
            if self.pres_ > ch.pressure then
                a = release
            end
            self.pres_ = self.pres_ - (self.pres_ - ch.pressure)*a
            
            
            local pt = ch.pitch + ch.pitchbend
            
            self.pitch = self.pitch - (self.pitch - pt)*0.002 
            
            self.f = getFreq(self.pitch)
            
            self.phase = self.phase + self.f
            
            local out = self.phase - math.floor(self.phase) - 0.5
            --local out = math.sin(self.phase*TWOPI)
            
            local samp = out*self.pres_
            
            
            self.dsampler.push(samp)
            
            if bit.band(i,1) == 0 then
                
                local samp2 =  self.dsampler.compute()


                self.dsampler2.push(samp2)
                
                
                
                if bit.band(i,2) == 0 then
                    local samp3 = self.dsampler2.compute()
                    
                    local i2 = bit.rshift(i, 2)
                
                    samples[0][i2] = samples[0][i2] + samp3*0.1 -- left
                    samples[1][i2] = samples[1][i2] + samp3*0.1 -- right
                end
                
                
            end
            
		    
        end
        
        --[[if self.pres_ < 0.001 and ch.noteOff then
            self.channel = 0
        end]]
     end
end

function polyGen.VTrack:noteOff(note, ev)
	local i = ev:getChannel()
    local ch = channels[i]
    print(i, "off")
    ch.pressure = 0
    ch.noteOff = true
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
    
    ch.noteOff = false
    
    ch.pitch = note
    
    ch.pressure = 0
    
    self.pitch = ch.pitch + ch.pitchbend
end


function getFreq(note)
	local f = 440 * 2^((note - 69)/12)
	return f/samplerate
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
