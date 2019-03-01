function tableToBytes(toIDS, fromIDS, cmdS, dataNST)	--a table of number/string
	local str = toIDS .. " " .. fromIDS .. " " .. cmdS .. " "
	if type(dataNST) == "table" then
		for i, vNS in ipairs(dataNST) do
			if type(vNS) == "number" or type(vNS) == "string" then
				str = str .. tostring(vNS) .. " "
			end
		end
	end

	local bytesNT = {}
	for i = 1 , string.len(str) do
		bytesNT[i] = string.byte(str,i)
	end
	return bytesNT
end

function bytesToTable(bytesNT)
	local str = ""
	for index, value in ipairs(bytesNT) do
		str = str .. string.char(bytesNT[index])
	end

	local toIDS
	local fromIDS
	local cmdS
	local dataNST = {}

	-- get only the first str as id
	local i = 1
	for valueS in string.gmatch(str, "%S+") do	 -- get each divided by space
		if i == 1 then toIDS = valueS 
		else if i == 2 then fromIDS = valueS 
		else if i == 3 then cmdS = valueS 
		else dataNST[i - 3] = tonumber(valueS) or valueS
		end end end
		i = i + 1
	end

	return toIDS, fromIDS, cmdS, dataNST
end

-------------------------------------------------------------------
function sendCMD(toidS, cmdS, txDataNT)
	local txBytesBT = tableToBytes(toidS, 
	                               getSelfIDS(), 
	                               cmdS,
	                               txDataNT)
	transData(txBytesBT)
end

-- get the first cmd, 
-- works only when there is supposed to receive only one cmd
function getCMD()
	for i, rxBytesBT in pairs(getReceivedDataTableBT()) do	-- byte table
		local toIDS, fromIDS, cmdS, rxNumbersNT = bytesToTable(rxBytesBT)
		if toIDS == getSelfIDS() then
			return fromIDS, cmdS, rxNumbersNT
		end
	end
end

-- get a cmd list from x (if x == nil, get every thing)
function getCMDListCT(x)		--CT:  cmd table(array)
	local i = 0
	local listCT = {}
	for _, rxBytesBT in pairs(getReceivedDataTableBT()) do	-- byte table
		local toIDS, fromIDS, cmdS, rxNumbersNT = bytesToTable(rxBytesBT)
		if toIDS == getSelfIDS() then
		if x == nil or fromIDS == x then
			i = i + 1
			listCT[i] = {
				fromIDS = fromIDS,
				cmdS = cmdS,
				dataNST = rxNumbersNT,
			}
		end end
	end

	return listCT
end
