require("include/protoplug")

local Filter = require("include/dsp/cookbook_svf")
local Line = require("include/dsp/fdelay_line")

local freq_ref = 523.2511

local freq_fine = 0
local freq = freq_ref
-- local freq = 522.97
local feedback = 0.9923

local ap_f = 6000
local ap_q = 0.5

local ap2_f = 6000
local ap2_q = 0.5

local fs = 44100

stereoFx.init()
function stereoFx.Channel:init()
	self.delay = Line(1024)

	self.ap = Filter({ type = "ap", f = ap_f, Q = ap_q })
	self.ap2 = Filter({ type = "ap", f = ap2_f, Q = ap2_q })
end

function stereoFx.Channel:update_filter()
	self.ap.update({ f = ap_f, Q = ap_q })
	self.ap2.update({ f = ap2_f, Q = ap2_q })
end

function stereoFx.Channel:processBlock(samples, smax)
	-- local ph_delay = self.ap.phaseDelay(freq) + self.ap2.phaseDelay(freq)
	local ph_delay = self.ap.phaseDelay(freq)

	for i = 0, smax do
		local s = samples[i]

		local d = self.delay.goBack((fs / freq) - ph_delay)
		d = self.ap.process(d)
		-- d = self.ap2.process(d)

		self.delay.push(s)

		samples[i] = s - feedback * d
	end
end

params = plugin.manageParams({
	{
		name = "freq",
		min = 50,
		max = 1000,
		changed = function(val)
			freq_ref = val
			freq = freq_ref + freq_fine
		end,
	},

	{
		name = "freq_fine",
		min = -1,
		max = 1,
		changed = function(val)
			freq_fine = val
			freq = freq_ref + freq_fine
		end,
	},

	{
		name = "feedback",
		min = 0.99,
		max = 1.0,
		changed = function(val)
			feedback = val
		end,
	},
	{
		name = "ap_f",
		min = 200,
		max = 9000,
		changed = function(val)
			ap_f = val
			stereoFx.LChannel:update_filter()
			stereoFx.RChannel:update_filter()
		end,
	},

	{
		name = "ap_q",
		min = 0.3,
		max = 1.0,
		changed = function(val)
			ap_q = val
			stereoFx.LChannel:update_filter()
			stereoFx.RChannel:update_filter()
		end,
	},

	{
		name = "ap2_f",
		min = 200,
		max = 15000,
		changed = function(val)
			ap2_f = val
			stereoFx.LChannel:update_filter()
			stereoFx.RChannel:update_filter()
		end,
	},

	{
		name = "ap2_q",
		min = 0.3,
		max = 1.0,
		changed = function(val)
			ap2_q = val
			stereoFx.LChannel:update_filter()
			stereoFx.RChannel:update_filter()
		end,
	},
})
