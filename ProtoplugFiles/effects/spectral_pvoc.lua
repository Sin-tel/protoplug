--[[
Spectral warping
some parts based on Mutable Instruments Clouds "Spectral Madness"
see: https://github.com/pichenettes/eurorack/tree/master/clouds/dsp/pvoc
]]

require "include/protoplug"

stereoFx.init()

fftlib = script.ffiLoad("libfftw3.so.3", "libfftw3-3", "libfftw3.3.dylib")


ffi.cdef[[
typedef double fftw_complex[2];
void *fftw_plan_dft_r2c_1d(int n, double *in, fftw_complex *out, unsigned int flags);
void *fftw_plan_dft_c2r_1d(int n, fftw_complex *in, double *out, unsigned int flags);
void fftw_execute(void *plan);
]]

-- settings
local fftSize = 4096
local steps = 4


-- 
pitch = 1.0
phase_random = 0
feedback = 0
quantize = 1
freeze = false
normalize = 0
warp = 0
minval = 0
randomstore = 0

-- useful constants
local lineMax = fftSize
local rescale = 0.5/(fftSize*steps)
local cplxSize = math.floor(fftSize/2+1)
local stepSize = fftSize/steps
local expct = 2*math.pi*stepSize/fftSize;

-- global buffers
local dbuf = ffi.new("double[?]", fftSize)
local spectrum = ffi.new("fftw_complex[?]", cplxSize)
local r2c = fftlib.fftw_plan_dft_r2c_1d(fftSize, dbuf, spectrum, 64)
local c2r = fftlib.fftw_plan_dft_c2r_1d(fftSize, spectrum, dbuf, 64)

local warpPolynomials = {
  { 0.0, 0.0, 1.0, 0.0 },
  { 0.0, 0.2, 0.8, 0.0 },
  { -1.4, 0.8, 0.6, 0.0 },
  { -7.3333, 9.0, -1.79167, 0.125 },
  { -7.3333, 9.0, -1.79167, 0.125 },
};




local TWOPI = 2*math.pi

local hw  = ffi.new("double[?]", fftSize) -- Hann window
for i = 0,fftSize-1 do
	hw[i] = (1 - math.cos(2*math.pi*i/(fftSize-1)))*rescale
end

local function ApplyWindow (samples)
	for i = 0,fftSize-1 do
		samples[i] = samples[i] * hw[i]
	end
end

local function wrap_phase(x)
    return (x + math.pi)%(TWOPI) - math.pi 
end

-- channel buffers
function stereoFx.Channel:init()
	self.inbuf = ffi.new("double[?]", lineMax)
	self.outbuf = ffi.new("double[?]", lineMax)
	self.bufi = 0
	
	
	self.phase = ffi.new("double[?]", cplxSize)
	self.phase_delta = ffi.new("double[?]", cplxSize)
	self.mag = ffi.new("double[?]", cplxSize)
	
	self.syn_phase = ffi.new("double[?]", cplxSize)
	self.syn_mag = ffi.new("double[?]", cplxSize)
	
	self.feedb_buf = ffi.new("double[?]", cplxSize)
end

local function ApplyFilter(self)
	-- setup
	for i=0,cplxSize-1 do
		self.syn_phase[i] = 0
		self.syn_mag[i] = 0
	end
	
	local pitch_ignore = (pitch == 1.0)
	
	
	-- cartesian to polar
	if not freeze then
        for i=0,cplxSize-1 do
            local real = spectrum[i][0] 
            local imag = spectrum[i][1] 
            local mag = 2*math.sqrt(real*real+imag*imag)
            local angle = math.atan2(imag, real)
            
            local fd = feedback
            if randomstore then
                if feedback < math.random() then
                    self.mag[i] = mag
                    self.feedb_buf[i] = self.mag[i]
                    self.phase_delta[i] = wrap_phase(angle - self.phase[i])
                    self.phase[i] = angle
                else
                    self.mag[i] = self.feedb_buf[i]
                    self.phase[i] =  wrap_phase(self.phase[i] + self.phase_delta[i] )
                end
            else
		
                self.mag[i] = mag*(1-fd) + self.feedb_buf[i]*fd
		

                self.feedb_buf[i] = self.mag[i]
                -- estimate instantaneous frequency
                self.phase_delta[i] = wrap_phase(angle - self.phase[i])
                self.phase[i] = angle
            end
        end
    else
        for i=0,cplxSize-1 do
            -- when frozen, the phase updates w estimated freq
            self.phase[i] =  wrap_phase(self.phase[i] + self.phase_delta[i] )
        end
    end
    
	-- do warp and pitch shift
    local coef = {0,0,1,0} 
    local pind = math.floor(warp) 
    local pfrac = warp - math.floor(warp)
    
    -- get polynomial coefficients    
    for i = 1,4 do
        local a = warpPolynomials[pind][i]
        local b = warpPolynomials[pind+1][i]
        coef[i] = a + (b - a)*pfrac
    end
	    
	
    local i2 = 0
    local increment = 1/pitch
    for i=0,cplxSize-1 do
        
    
        local x = i / (cplxSize-1)
        -- compute polynimial warping
        x = coef[4] + x*(coef[3] +x*(coef[2] + x*coef[1]))
        x = x*(cplxSize-1)
            
        i2 = x*increment
        local ind = math.floor(i2)
        local frac = i2 - math.floor(i2)
	    
        if i2<cplxSize and i2>0 then
            local mag_a = self.mag[ind]
            local mag_b = self.mag[ind+1]
                
            local ph_a = self.phase[ind]
            local ph_b = self.phase[ind+1]
		
            self.syn_mag[i] = mag_a + (mag_b - mag_a) * frac 
            
            -- interpolate phase
            -- no attempt is made to correct for the pitch shift
            self.syn_phase[i] = wrap_phase(ph_a  + wrap_phase(ph_b  - ph_a ) * frac)
        end
            
    end
    
    
    --update mag
    local max = 0
    for i=0,cplxSize-1 do
        if self.syn_mag[i] > max then
            max = self.syn_mag[i]
        end
    end
    max = max + 0.00001
    local invmax = 1/max
    
	local invquant = 1 / quantize
	
	for i=0,cplxSize-1 do
	    self.syn_mag[i] = self.syn_mag[i]*invmax
	    if self.syn_mag[i] < minval then
	        self.syn_mag[i] = 0
	    end
        if quantize > 0 then
            self.syn_mag[i] = invquant*math.floor(self.syn_mag[i]*quantize)
        end
        local x = self.syn_mag[i]
        local w = 2*x * (1-x) * (1-x) * (1-x)
        
        
        self.syn_mag[i] = (x + (w-x)*normalize)*max
    end
    
    
    -- phase randomisation
    for i=0,cplxSize-1 do
		self.syn_phase[i] = self.syn_phase[i] + TWOPI*phase_random*(math.random()-0.5)
	end
	
	-- resynthesis
	for i=0,cplxSize-1 do
		local mag = self.syn_mag[i]
		local phase = self.syn_phase[i]
	
		spectrum[i][0] = mag * math.cos(phase)
		spectrum[i][1] = mag * math.sin(phase)
	end

end

function wrap (i)
	return (i>lineMax-1) and i-lineMax or i
end

function stereoFx.Channel:processBlock(s, smax)
	for i = 0,smax do
		self.inbuf[self.bufi] = s[i] + 0.0001*math.random()
		s[i] = self.outbuf[self.bufi]
		self.outbuf[self.bufi] = 0
		if self.bufi%stepSize==0 then
			for j=0,fftSize-1 do
				dbuf[j] = self.inbuf[wrap(self.bufi+j)]
			end
			-- revive cdata (inexplicably required, todo-narrow down the cause):
			tostring(dbuf); tostring(spectrum)
			fftlib.fftw_execute(r2c)
			ApplyFilter (self)
			fftlib.fftw_execute(c2r)
			ApplyWindow(dbuf)
			for j=0,fftSize-1 do
				self.outbuf[wrap(self.bufi+j)] =
				 self.outbuf[wrap(self.bufi+j)] + dbuf[j]
			end
		end
		self.bufi = wrap(self.bufi+1)
	end
end



params = plugin.manageParams {
	{
		name = "pitch";
		min = -12;
		max = 12;
		type = "double";
		default = 0;
		changed = function(val) 
		    local c = 0.2
		    val = val - math.max(-c,math.min(c,val))
		    pitch = 2^(val/12) 
		end;
	};
	{
		name = "warp";
		min = 1;
		max = 4;
		type = "double";
		default = 0;
		changed = function(val) warp = val end;
	};
	{
		name = "random phase";
		min = 0;
		max = 1;
		type = "double";
		default = 0;
		changed = function(val) phase_random = val end;
	};

	{
		name = "feedback";
		min = 0;
		max = 1;
		type = "double";
		default = 0;
		changed = function(val) feedback = val*(2-val) end;
	};
	{
		name = "normalize";
		min = 0;
		max = 1;
		type = "double";
		default = 0;
		changed = function(val) normalize = val end;
	};
	{
		name = "quantize";
		min = 0;
		max = 1;
		type = "double";
		default = 0;
		changed = function(val) 
		if val > 0 then
		    quantize = 255*(1-val)*(1-val)+0.0001 
		else
		    quantize = 0
		end
		
		end;
	};
	{
		name = "dropout";
		min = 0;
		max = 1;
		type = "double";
		default = 1;
		changed = function(val) minval = val*val end;
	};
	
	{
		name = "freeze";
		type = "list";
		values = {"off"; "on"};
		default = "off";
		changed = function(val) freeze = (val == "on") end;
	};
		{
		name = "fdback type";
		type = "list";
		values = {"normal"; "random bins"};
		default = "normal";
		changed = function(val) randomstore = (val == "random bins") end;
	};
}