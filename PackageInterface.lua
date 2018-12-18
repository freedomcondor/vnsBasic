function tableToBytes(toID, fromID, cmd, x_nt)	--a table of numbers
	local str = toID .. " " .. fromID .. " " .. cmd .. " "
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

	local toID
	local fromID
	local cmd
	local data = {}

	-- get only the first str as id
	local i = 1
	for value in string.gmatch(str, "%S+") do	 -- get each divided by space
		if i == 1 then toID = value 
		else if i == 2 then fromID = value 
		else if i == 3 then cmd = value 
		else data[i - 3] = tonumber(value)
		end end end
		i = i + 1
	end

	return toID, fromID, cmd, data
end
