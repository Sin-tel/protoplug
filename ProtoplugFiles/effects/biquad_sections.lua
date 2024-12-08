require("include/protoplug")

-- local function biquad(b0, b1, b2, a1, a2)
-- 	b0 = b0 or 0.095
-- 	b1 = b1 or 0
-- 	b2 = b2 or -0.095
-- 	a1 = a1 or -1.8
-- 	a2 = a2 or 0.810
-- 	local x1, x2, y1, y2 = 0, 0, 0, 0
-- 	local public = {
-- 		process = function(input)
-- 			local out = (b0 * input + b1 * x1 + b2 * x2) - (a1 * y1 + a2 * y2)
-- 			x2 = x1
-- 			x1 = input
-- 			y2 = y1
-- 			y1 = out
-- 			return out
-- 		end,
-- 	}
-- 	return public
-- end

local coefs = {
	{ 0.45328957908122547, 0.7686782786595062 },
	{ -1.5098031998327097, 0.8239691505427698 },
	{ -0.33497616563701826, 0.8497162209521576 },
	{ 0.860532778806777, 0.864831953998177 },
	{ 1.8383980950656635, 0.8750976079423651 },
	{ 0.9720135881852688, 0.8982368622477198 },
	{ 1.173112017875603, 0.9067041824605129 },
	{ 1.7598741541427003, 0.9271552942664993 },
	{ 1.5081917274183538, 0.9298550192905908 },
	{ -1.8607103524881348, 0.9336018450017749 },
	{ -1.462080928110776, 0.9389652563278186 },
	{ -0.1620443846063706, 0.9458750768807593 },
	{ -1.9374545625894626, 0.949454091888979 },
	{ 1.6899554811919664, 0.9516534309321144 },
	{ 1.898723079483124, 0.961030339128142 },
	{ -1.5817346397971968, 0.963523776676408 },
	{ 0.0893548805416613, 0.9640609704546556 },
	{ -0.5268430550743128, 0.964284489870628 },
	{ 0.3256936207073312, 0.9701521894320296 },
	{ -0.7553949489740376, 0.9743922474701027 },
	{ -1.136364461113983, 0.9759650682204392 },
	{ -1.9360772990750237, 0.9779161173074749 },
}

local function biquad(a1, a2)
	a1 = a1 or 0.0
	a2 = a2 or 0.0
	local y1, y2 = 0, 0
	local public = {
		process = function(input)
			local out = input - a1 * y1 - a2 * y2
			y2 = y1
			y1 = out
			return out
		end,
	}
	return public
end

stereoFx.init()

function stereoFx.Channel:init()
	self.sections = {}
	for i, c in ipairs(coefs) do
		print(c[1], c[2])
		self.sections[i] = biquad(c[1], c[2])
	end
end

function stereoFx.Channel:processBlock(samples, smax)
	for i = 0, smax do
		local s = samples[i]

		for _, v in ipairs(self.sections) do
			s = v.process(s)
		end

		samples[i] = s
	end
end
