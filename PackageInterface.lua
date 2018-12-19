function tableToBytes(toID_s, fromID_s, cmd_s, data_nt)	--a table of numbers
	local str = toID_s .. " " .. fromID_s .. " " .. cmd_s .. " "
	if type(data_nt) == "table" then
		for index, value_n in ipairs(data_nt) do
			if type(value_n) == "number" then
				str = str .. tostring(value_n) .. " "
			end
		end
	end

	local bytes_nt = {}
	for i = 1 , string.len(str) do
		bytes_nt[i] = string.byte(str,i)
	end
	return bytes_nt
end

function bytesToTable(bytes_nt)
	local str = ""
	for index, value in ipairs(bytes_nt) do
		str = str .. string.char(bytes_nt[index])
	end

	local toID_s
	local fromID_s
	local cmd_s
	local data_nt = {}

	-- get only the first str as id
	local i = 1
	for value_s in string.gmatch(str, "%S+") do	 -- get each divided by space
		if i == 1 then toID_s = value_s 
		else if i == 2 then fromID_s = value_s 
		else if i == 3 then cmd_s = value_s 
		else data_nt[i - 3] = tonumber(value_s)
		end end end
		i = i + 1
	end

	return toID_s, fromID_s, cmd_s, data_nt
end
