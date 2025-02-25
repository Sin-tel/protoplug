-- fractional delay with lagrange interpolation

local function FLine(bufSize)
	local n, e = math.frexp(bufSize)
	bufSize = 2 ^ e --nextpoweroftwo
	local buf = ffi.new("double[?]", bufSize)
	local mask = bufSize - 1
	local h = { [0] = 0, 0, 0, 0 }
	local pos = 0
	local ptL = 0
	local lastdt = math.huge
	local function CalcCoeffs(delay)
		local intd = math.floor(delay)
		local Dm1 = delay - intd
		intd = intd - 1.
		local D = Dm1 + 1
		local Dm2 = Dm1 - 1
		local Dm3 = Dm1 - 2
		local DxDm1 = D * Dm1
		local Dm2xDm3 = Dm2 * Dm3
		h[0] = (-1 / 6.) * Dm1 * Dm2xDm3
		h[1] = 0.5 * D * Dm2xDm3
		h[2] = -0.5 * DxDm1 * Dm3
		h[3] = (1 / 6.) * DxDm1 * Dm2
		return intd
	end
	return {
		goBack = function(dt)
			dt = dt - 1
			if dt ~= lastdt then
				ptL = CalcCoeffs(dt)
				lastdt = dt
			end
			local sum = 0
			for i = 0, 3 do
				sum = sum + buf[bit.band((pos + ptL + i), mask)] * h[i]
			end
			return sum
		end,
		goBack_int = function(dt)
			-- todo assert dt<bufSize
			local fpos = pos + dt + 1
			local ipos1 = math.floor(fpos)
			return buf[bit.band(ipos1, mask)]
		end,
		push = function(s)
			pos = pos - 1
			if pos < 0 then
				pos = mask
			end
			buf[pos] = s
		end,
		zero = function()
			for i = 0, bufSize - 1 do
				buf[i] = 0
			end
		end,
	}
end

return FLine
