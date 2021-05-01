require "include/protoplug"

local attack = 0.005
local release = 0.005

local oversample = 2
local samplerate = 44100*oversample

polyGen.initTracks(8)

pedal = false

local TWOPI = 2*math.pi


local FILTER_TAP_NUM = 31

local filter_taps_ = {
  -3.15622016e-04,  0.00000000e+00,  1.76790330e-03,  0.00000000e+00,
 -5.20927712e-03,  0.00000000e+00,  1.19903110e-02,  0.00000000e+00,
 -2.42536137e-02,  0.00000000e+00,  4.65939093e-02,  0.00000000e+00,
 -9.50049102e-02,  0.00000000e+00,  3.14457346e-01,  5.00000000e-01,
  3.14457346e-01,  0.00000000e+00, -9.50049102e-02,  0.00000000e+00,
  4.65939093e-02,  0.00000000e+00, -2.42536137e-02,  0.00000000e+00,
  1.19903110e-02,  0.00000000e+00, -5.20927712e-03,  0.00000000e+00,
  1.76790330e-03,  0.00000000e+00, -3.15622016e-04}

local filter_taps = ffi.new("double[?]", FILTER_TAP_NUM)

for i = 0,FILTER_TAP_NUM-1 do
    filter_taps[i] = filter_taps_[i+1]
end



local function computefilter(line, ind)
    local s = 0
    for i = 0,FILTER_TAP_NUM-1  do
        local j = ind + i
        if j >= FILTER_TAP_NUM then
            j = j - FILTER_TAP_NUM
        end
        s = s + filter_taps[i] * line[j]
    end
    return s
    --return line[ind]
end

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
	
	self.filterline = ffi.new("double[?]", FILTER_TAP_NUM)
	
	for i = 0,FILTER_TAP_NUM-1 do
	    self.filterline[i] = 0
	end
  
    
    self.find = 0
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
    
    local i2 = 0
    local i3 = 0
    
    if ch then
        for i = 0,smax*oversample do
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
            
            local samp = out*self.pres_
            
            self.filterline[self.find] = samp
            
            i2 = i2 + 1
            if i2 >= oversample then
                i2 = 0
                
                local samp2 = computefilter(self.filterline,self.find)
                
                samples[0][i3] = samples[0][i3] + samp2*0.1 -- left
                samples[1][i3] = samples[1][i3] + samp2*0.1 -- right
                
                i3 = i3 + 1
            end
            
		    self.find = self.find + 1
            if self.find >= FILTER_TAP_NUM then
                self.find = 0
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
