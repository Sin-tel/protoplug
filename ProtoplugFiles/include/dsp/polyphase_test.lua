local Polyphase = require("polyphase")

local TEST_COEFFICIENTS = {
	0.07711508,
	0.26596853,
	0.48207062,
	0.66510415,
	0.79682046,
	0.8841015,
	0.94125146,
	0.9820054,
}

local filter = Polyphase.new(TEST_COEFFICIENTS)

-- Test input (upsampled signal)
local INPUT_DOWN = {
	1.0,
	1.0,
	-1.0,
	-1.0,
	1.0,
	1.0,
	-1.0,
	-1.0,
	1.0,
	1.0,
	-1.0,
	-1.0,
	1.0,
	1.0,
	-1.0,
	-1.0,
}

-- Expected output from HIIR (downsampled)
local EXPECTED_DOWN = {
	0.09073097,
	0.4736801,
	0.0851654,
	-0.3646181,
	0.41357678,
	-0.34386525,
	0.22569576,
	-0.0966016,
}

for k = 1, #EXPECTED_DOWN do
	local u = filter.downsample(INPUT_DOWN[k * 2 - 1], INPUT_DOWN[k * 2])
	print(u, EXPECTED_DOWN[k])
	assert((u - EXPECTED_DOWN[k]) < 1e-6)
end

-- Test input (upsampled signal)
local INPUT_UP = {
	1.0,
	0.5,
	0.0,
	-0.5,
	-1.0,
	-0.5,
	0.0,
	0.5,
}

-- Expected output from HIIR (upsampled)
local EXPECTED_UP = {
	0.027881498,
	0.15358044,
	0.4338964,
	0.78565663,
	0.9552737,
	0.7268284,
	0.19159412,
	-0.282385,
	-0.45259422,
	-0.47481412,
	-0.6492536,
	-0.94076306,
	-0.9814316,
	-0.58784556,
	-0.05244851,
	0.23429948,
}

filter.reset_state()
-- filter = Polyphase()

print("Testing upsample")

for k = 1, #INPUT_UP do
	local u0, u1 = filter.upsample(INPUT_UP[k])

	print(u0, EXPECTED_UP[k * 2 - 1])
	assert(u0 - EXPECTED_UP[k * 2 - 1] < 1e-7)
	print(u1, EXPECTED_UP[k * 2])
	assert(u1 - EXPECTED_UP[k * 2] < 1e-7)
end
