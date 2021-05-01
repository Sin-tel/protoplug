require "include/protoplug"

attack = 0.005
release = 0.005

polyGen.initTracks(15)

pedal = false

TWOPI = 2*math.pi


function newChannel()
    new = {}
    
    new.pressure = 0
    new.pres_ = 0
    new.f_ = 0
    
    new.phase = 0
	new.f = 0
	new.pitch = 0
	new.pitchbend = 0

	new.vel = 0
	
	new.fdbck = 0
	
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
            channels[ch].pressure = msg:getPressure()/127
        end
    end
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    local ch = channels[self.channel]
    
    if ch then
    
        for i = 0,smax do
        
            local a = attack
            if ch.pres_ > ch.pressure then
                a = release
            end
            ch.pres_ = ch.pres_ - (ch.pres_ - ch.pressure)*a
            ch.f_ = ch.f_ - (ch.f_ - ch.f)*0.002
            
		
            ch.phase = ch.phase + (ch.f_*TWOPI)
		
		
            local out = math.sin(ch.phase + ch.fdbck)*ch.pres_
		
            ch.fdbck = out
		
            samples[0][i] = samples[0][i] + out*0.3 -- left
            samples[1][i] = samples[1][i] + out*0.3 -- right
        end
        
     end
end

function polyGen.VTrack:noteOff(note, ev)
	local i = ev:getChannel()
    local ch = channels[i]
end

function polyGen.VTrack:noteOn(note, vel, ev)
    local i = ev:getChannel()
    
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
    
    setPitch(ch)
    ch.f_ = ch.f
    
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
