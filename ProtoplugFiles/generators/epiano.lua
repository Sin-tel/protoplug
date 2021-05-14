--[[
physical model of an electric piano pickup

]]


 require "include/protoplug"

local release = 0.03*44100
local releaseRate =  1 - 1/release

local decay = 1.2*44100
local decayRate =  1 - 1/decay

local decay2 = 0.06*44100
local decayRate2 =  1 - 1/decay2


fifth = 6.956 --fifth in semitones
notes = {}

center = 0

polyGen.initTracks(24)

pitchbend = 0

pedal = false

gain = 1

x0=0.5
y0 = 0.5

function polyGen.VTrack:init()
	-- create per-track fields here
	self.phase = 0
	self.f = 0
	self.pitch = 0
	self.fdbck = 0
	self.env = 0
	self.attack  = 0
	self.vel = 0
	self.bright = 0
	self.finished = false
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
	    if self.env < 0.001 then self.env = 0; break end
	    
	    self.attack = self.attack + 1/40
	    
	    if self.attack >= 1.0 then
	        self.attack = 1.0
	    end
	    if self.decay and not pedal or self.finished then   
	        self.finished = true
            self.env = self.env*releaseRate
        else
            self.env = self.env*decayRate
        end
        
        self.env2 = self.env2 * decayRate2
        if self.env2 < 0.001 then self.env2 = 0 end
        
        
		
		self.phase = self.phase + (self.f*math.pi*2)
		
		self.phase2 = self.phase2 + ((self.f+1.3/44100)*math.pi*2)
		
		self.phase3 = self.phase3 + ((self.f2*0.5)*math.pi*2)
		
		self.phase4 = self.phase4 + ((self.f2*2+20/44100)*math.pi*2)

		
		
		local amp = self.env*self.attack*self.vel
		
		
		local s1 = math.sin(self.phase)
		local s2 = math.sin(self.phase2)
		
		local s3 = math.sin(self.phase3)*self.env2*0.01
		local s4 = math.sin(self.phase4)*self.env2*0.01
		

        
        local d = (s1+0.13*s2 + s3+s4)*0.8*gain*amp
		
		d = 1.0 / math.sqrt(y0*y0 + (d-x0)*(d-x0))
		
		d = d - 1.0 / math.sqrt(y0*y0 + x0*x0)
		
		
		local trackSample = 3*(y0*y0)*d/gain
		
		
		
		samples[0][i] = samples[0][i] + trackSample -- left
		samples[1][i] = samples[1][i] + trackSample -- right
	end
end

function polyGen.VTrack:noteOff(note, ev)
	local ind = nil
	for i,v in ipairs(notes) do
	    if v == note then
	        ind = i
	    end
	end
	if ind then
	    table.remove(notes,ind)
	end
	self.decay = true

	--temperNotes()
end

function polyGen.VTrack:noteOn(note, vel, ev)
    self.attack = 0
    self.decay = false
    self.env2 = 1
    self.finished = false
    self.env = 1
    
    
    
    table.insert(notes,note)
    table.sort(notes)
  
    self.pitch = self.note--temper(self.note)
    self.f = getFreq(self.pitch+pitchbend)
    
    self.f2 = getBellFreq(self.pitch+pitchbend)
  
    
	self.phase = 0
	self.phase2 = 0
	self.phase3 = 0
	self.phase4 = 0
	--self.vel = 0.0+1.0*(vel/127)^2
	self.vel = 2^((vel-127)/30)
	self.bright = math.min(2.0,0.005/self.f)
	
	--print(0.005/self.f)
end

function temper(note)
	local index = (note)%12
	local oct = note - index
	
	local cround = math.floor(center + 0.5)
	
	local pos = (((index)*7 + 5 - cround)%12 - 5)
	
	if pos ~= 6 then
        center = center + (pos)*0.25
	end
	
	
	--print(cround,pos,((pos + cround)*6.95)%12)
	print(cround,pos,index + (pos + cround)*(fifth - 7))
	
	return oct + index + (pos + cround)*(fifth - 7)
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
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	--[[{
		name = "Size of fifth";
		min = 6.66;
		max = 7.2;
		default = 6.97;
		changed = function(val) fifth = val end;
	};
	{
		name = "Reset"; 
		min = 0;
		max = 1;
		default = 0;
		changed = function(val) center = 0 end;
	};]]
	{
		name = "asymmetry";
		min = 0;
		max = 2;
		default = 0.5;
		changed = function(val) x0 = val end;
	};
	{
		name = "pickup distance";
		min = 0.1;
		max = 2;
		default = 0.5;
		changed = function(val) y0 = val end;
	};
	{
		name = "gain";
		min = 0.5;
		max = 5;
		default = 1;
		changed = function(val) gain = val end;
	};
}
