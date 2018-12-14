function tableToBytes(x_nt)	--a table of numbers
	local str = ""
	if type(x_nt) == "table" then
		for index, value in ipairs(x_nt) do
			if type(value) == "number" then
				str = str .. tostring(value) .. " "
			end
		end
	end

	local bytes = {}
	for i = 1 , string.len(str) do
		bytes[i] = string.byte(str,i)
	end
	return bytes
end

function bytesToTable(bytes_nt)
	local str = ""
	for index, value in ipairs(bytes_nt) do
		str = str .. string.char(bytes_nt[index])
	end

	local a = {}
	local i = 0
	for value in string.gmatch(str, "%S+") do	 -- get each divided by space
		i = i + 1
		a[i] = tonumber(value)
	end
	return a
end
