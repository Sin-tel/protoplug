-- local test_coefs = { 0.07711508, 0.26596853, 0.48207062, 0.66510415, 0.79682046, 0.8841015, 0.94125146, 0.9820054 }

local Polyphase = {}

Polyphase.presets = {}

Polyphase.presets.coef_8 = {
	0.044076093956155402,
	0.16209555156378622,
	0.32057678606990592,
	0.48526821501990786,
	0.63402005787429128,
	0.75902855561016014,
	0.86299283427175177,
	0.9547836337311687,
}

Polyphase.presets.coef_10 = {
	0.026280277370383145,
	0.099994562200117765,
	0.20785425737827937,
	0.33334081139102473,
	0.46167004060691091,
	0.58273462309510859,
	0.69172302956824328,
	0.78828933879250873,
	0.87532862123185262,
	0.9580617608216595,
}

Polyphase.presets.coef_12 = {
	0.017347915108876406,
	0.067150480426919179,
	0.14330738338179819,
	0.23745131944299824,
	0.34085550201503761,
	0.44601111310335906,
	0.54753112652956148,
	0.6423859124721446,
	0.72968928615804163,
	0.81029959388029904,
	0.88644514917318362,
	0.96150605146543733,
}

function Polyphase.new(in_coef)
	local coef = {}
	local state = {}

	local n = #in_coef

	assert(n % 2 == 0, "coefs must be even")

	for i = 1, n do
		coef[i] = in_coef[i]
		state[i] = 0
	end

	state[n + 1] = 0
	state[n + 2] = 0

	local process_sample = function(s0, s1)
		assert(n > 0)
		for k = 1, (n / 2) do
			local i = k * 2

			local t0 = (s0 - state[i + 1]) * coef[i - 1] + state[i - 1]
			local t1 = (s1 - state[i + 2]) * coef[i] + state[i]

			state[i - 1] = s0
			state[i] = s1

			s0 = t0
			s1 = t1
		end

		state[n + 1] = s0
		state[n + 2] = s1

		return s0, s1
	end

	return {
		process_sample = process_sample,

		process_sample_neg = function(s0, s1)
			for k = 1, (n / 2) do
				local i = k * 2

				local t0 = (s0 + state[i + 1]) * coef[i - 1] - state[i - 1]
				local t1 = (s1 + state[i + 2]) * coef[i] - state[i]

				state[i - 1] = s0
				state[i] = s1

				s0 = t0
				s1 = t1
			end

			state[n + 1] = s0
			state[n + 2] = s1

			return s0, s1
		end,

		reset_state = function()
			for i = 1, n + 2 do
				state[i] = 0
			end
		end,

		upsample = function(s)
			return process_sample(s, s)
		end,

		downsample = function(s0, s1)
			local u0, u1 = process_sample(s0, s1)

			return 0.5 * (u0 + u1)
		end,
	}
end

return Polyphase
