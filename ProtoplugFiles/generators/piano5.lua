--[[
another attempt at piano
]]

require("include/protoplug")

local Filter = require("include/dsp/cookbook_svf")
local Line = require("include/dsp/fdelay_line")

polyGen.initTracks(16)

local release = 0.99
local decay = 0.99

local position = 0.2

local pedal = false

local tun_m = 1

local coupling = 0

local n_harm = 16

local unison_width = 0

local f_weights = require("generators/piano_weights")

function polyGen.VTrack:init()
	-- create per-track fields here

	self.pitch = 0
	self.vel = 0
	self.finished = true

	self.len = { 20, 20, 20 }
	self.string_s = { 0, 0, 0 }
	self.f_weights = {}
	self.f_phase = {}

	self.len_corr = 0

	self.position = 0.132

	self.integrate = 0

	self.decay = 0.99
	self.release = 0.99

	self.coupling = 0.0025

	self.hammer_t = 1.0
	self.hammer_f = 1.0
	self.hammer_t2 = 1.0
	self.hammer_f2 = 1.0

	self.n_delays = 1

	self.delay = {}
	self.delay[1] = Line(1024)
	self.delay[2] = Line(1024)
	self.delay[3] = Line(1024)
	self.delay_hammer = Line(1024)

	self.done_timer = 0
	self.active = false

	self.h_t = 0

	self.r = 0.77

	self.ap = {
		Filter({
			type = "ap",
		}),
		Filter({
			type = "ap",
		}),
		Filter({
			type = "ap",
		}),
	}

	self.loop_filter = {
		Filter({
			type = "hs",
		}),
		Filter({
			type = "hs",
		}),
		Filter({
			type = "hs",
		}),
	}

	self.noise_filter = Filter({
		type = "lp",
		f = 10,
		Q = 0.7,
	})
	self.noise_filter2 = Filter({
		type = "lp",
		f = 10,
		Q = 0.7,
	})

	self.dc_kill = Filter({
		type = "hp",
		f = 30,
		Q = 0.7,
	})
end

function processMidi(msg)
	if msg:isControl() then
		if msg:getControlNumber() == 64 then
			pedal = msg:getControlValue() ~= 0
		end
	end
end

local function get_freq(note)
	local n = note - 69
	local f = 440 * 2 ^ (n / 12)
	return (f / 44100)
end

local function smoothstep(x)
	x = math.min(math.max(x, 0), 1)
	-- return 3 * x ^ 2 - 2 * x ^ 3
	return 0.5 - 0.5 * math.cos(math.pi * x)
end

local TWO_PI = 2 * math.pi

function polyGen.VTrack:addProcessBlock(samples, smax)
	if self.active then
		for i = 0, smax do
			local nse = math.random() - 0.5
			local s = 0

			local a = 4
			local a2 = 4
			local t = self.hammer_t
			local t2 = self.hammer_t2
			local w = 0
			if t < 1.0 then
				if t < 1 / a then
					w = smoothstep(a * t)
				elseif 1 - (1 / a2) < t then
					w = smoothstep(a2 * (1 - t))
				else
					w = 1.0
				end

				for n = 1, n_harm do
					s = s + math.sin(n * TWO_PI * t2 + self.f_phase[n]) * self.f_weights[n]
				end

				s = s * w
				s = s * self.vel
			end

			self.hammer_t = self.hammer_t + self.hammer_f
			self.hammer_t2 = self.hammer_t2 + self.hammer_f2

			nse = nse * w
			nse = self.noise_filter.process(nse)
			nse = self.noise_filter2.process(nse)
			s = s + nse * 0.2

			s = self.dc_kill.process(s)

			-- local hs1 = self.delay_hammer.goBack(self.len[1] * 0.125)
			-- local hs2 = self.delay_hammer.goBack(self.len[1] * 0.25)
			-- self.delay_hammer.push(s)
			-- s = s - 0.206 * hs1 - 0.427 * hs2

			if self.finished and not pedal then
				self.decay = 0.99 * self.decay + 0.01 * self.release
				self.done_timer = self.done_timer + 1 / 44100
				if self.done_timer > 0.5 then
					self.active = false
					break
				end
			end
			local damp = self.decay

			local string_total = 0
			for k = 1, self.n_delays do
				local ds = self.delay[k].goBack(self.len[k] * (1 / tun_m) + self.len_corr)
				ds = ds * damp
				ds = self.ap[k].process(ds)
				ds = self.loop_filter[k].process(ds)
				self.string_s[k] = ds
				string_total = string_total + ds
			end
			string_total = string_total / self.n_delays

			for k = 1, self.n_delays do
				local ds = self.string_s[k]
				self.delay[k].push(ds - string_total * 2 * self.coupling + s)
			end

			local out = string_total + 0.3 * s

			samples[0][i] = samples[0][i] + out -- left
			samples[1][i] = samples[1][i] + out -- right
		end
	end
end

function polyGen.VTrack:noteOff(note, ev)
	self.finished = true
	self.done_timer = 0
end

function polyGen.VTrack:noteOn(note, vel, ev)
	self.finished = false
	self.active = true

	local f = get_freq(note)

	self.n_delays = 3
	self.len[1] = 1.0 / f
	local d1 = 0.5 + math.random()
	local d2 = 0.5 + math.random()
	self.len[2] = (1.0 + unison_width * 0.00100 * d1) / f
	self.len[3] = (1.0 - unison_width * 0.00163 * d2) / f

	local f_alpha = vel / 64
	local f_i = 1
	if f_alpha >= 1.0 then
		f_i = 2
		f_alpha = f_alpha - 1
	end
	if note <= 38 then
		self.n_delays = 1
		self.len[1] = 1.0 / f
	elseif note <= 50 then
		self.n_delays = 2
		self.len[1] = 0.9998 / f
		self.len[2] = 1.0002 / f
	end

	do
		local t = (note / 12) - 2
		if t <= 1.0 then
			t = 1.0
		end
		if t >= 5.999 then
			t = 5.999
		end
		local t_index = math.floor(t)
		local t_frac = t - t_index

		for k = 1, n_harm do
			if k * f < 20000 then
				local w1a = f_weights[t_index][f_i][k] or -100
				local w2a = f_weights[t_index][f_i + 1][k] or -100
				local w_dba = (1.0 - f_alpha) * w1a + f_alpha * w2a

				local w1b = f_weights[t_index + 1][f_i][k] or -100
				local w2b = f_weights[t_index + 1][f_i + 1][k] or -100
				local w_dbb = (1.0 - f_alpha) * w1b + f_alpha * w2b

				local w_db = (1 - t_frac) * w_dba + t_frac * w_dbb

				self.f_weights[k] = 10 ^ (w_db / 20)
			else
				self.f_weights[k] = 0
			end

			-- self.f_phase[k] = math.random() * TWO_PI
			-- self.f_phase[k] = math.random() * TWO_PI * 0.1
			self.f_phase[k] = math.pi
		end
	end

	local d_range = 0.02
	local v = d_range * math.exp(-math.log(d_range) * (vel / 127) ^ 0.8)

	local ww = (note - 69) / 6
	local v_off = ww - 0.2 * ww ^ 2
	self.vel = v * 10 ^ (v_off / 20)

	local c_off = 2 ^ (-0.04 * (note - 69))
	self.coupling = coupling * c_off

	self.position = position

	local h_off = 0.2 / (note / 127)

	self.hammer_t = 0.0
	self.hammer_f = f * h_off
	-- self.hammer_f = f

	self.hammer_t2 = 0.0
	self.hammer_f2 = f

	self.decay = math.pow(decay, 0.001 / f)
	self.release = math.pow(release, 0.003 / f)

	local nlpf = 3000 * math.sqrt(f) + v * 2000
	-- local nlpf = 8000 * math.sqrt(f) + v * 2000
	self.noise_filter.update({
		f = nlpf,
		Q = 0.7,
	})
	self.noise_filter2.update({
		f = nlpf,
		Q = 0.7,
	})

	local w = note / 127
	local apo = 1 / (0.39 - 1.73 * w + 2.23 * w * w)
	-- local apo = 1 / (0.33 - 1.13 * w + 1.41 * w * w)
	local apf = 44100 * f * apo
	local apq = 0.5
	self.ap[1].update({ f = apf, Q = apq })
	self.ap[2].update({ f = apf, Q = apq })
	self.ap[3].update({ f = apf, Q = apq })

	local ph_delay = self.ap[1].phaseDelay(f)

	local fgain = -0.002 / f
	local fq = 0.707
	local ff = 6000
	self.loop_filter[1].update({ gain = fgain, f = ff, Q = fq })
	self.loop_filter[2].update({ gain = fgain, f = ff, Q = fq })
	self.loop_filter[3].update({ gain = fgain, f = ff, Q = fq })

	local ph_delay2 = self.loop_filter[1].phaseDelay(f)

	self.len_corr = -ph_delay - ph_delay2
end

params = plugin.manageParams({
	{
		name = "decay",
		min = 3,
		max = 12,
		default = 6.2,
		changed = function(val)
			decay = 1.0 - math.exp(-val)
			print(decay)
		end,
	},
	{
		name = "release",
		min = 1.5,
		max = 3,
		default = 2,
		changed = function(val)
			release = 1.0 - math.exp(-val)
		end,
	},
	{
		name = "Tune master",
		min = -400,
		max = 400,
		default = 0,
		changed = function(val)
			tun_m = 2 ^ (val / 1200)
		end,
	},
	{
		name = "Coupling",
		min = 0,
		max = 0.01,
		default = 0.0029,
		changed = function(val)
			coupling = val
		end,
	},
	{
		name = "Unison Width",
		min = 0,
		max = 1.0,
		default = 0.28,
		changed = function(val)
			unison_width = val
		end,
	},
})

params.resetToDefaults()
