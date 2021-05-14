--[[
delay line 1
with dc filter and shitty linear interpolation

TODO bit band
]]


local function blend(a,b,p) return (a*p + b*(1-p)) end

function Line (bufSize)
	local n,e = math.frexp(bufSize)
	bufSize = 2^e --nextpoweroftwo
	local buf = ffi.new("double[?]", bufSize)
	local mask = bufSize - 1

	local pos = 0 -- todo int
	local dc1, dc2 = 0, 0
	return {
		goBack = function (dt)
			-- todo assert dt<bufSize
			local fpos = pos - dt
			local ipos1 = math.floor(fpos)
			local frac = fpos - ipos1

			return blend(buf[bit.band(ipos1 + 1, mask)], buf[bit.band(ipos1, mask)], frac)
		end;
		goBack_int = function (dt)
			-- todo assert dt<bufSize
			local fpos = pos - dt + 1 
			local ipos1 = math.floor(fpos)
			return buf[bit.band(ipos1, mask)]
		end;
		push = function (s)
			pos = pos + 1
			if pos >= bufSize then pos = 0 end
			--[[dc1 = dc1 + (s - dc2) * 0.000002
			dc2 = dc2 + dc1
			dc1 = dc1 * 0.96
						if (pos)>=bufSize or (pos)<0 then error("accessed buf "..(pos)) end -- DEBUG
			buf[pos] = s - dc2]]
			buf[pos] = s
		end;
	}
end

return Line
