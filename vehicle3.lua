----------------------------------------------------------------------------------
--   Global Variables
----------------------------------------------------------------------------------

require("PackageInterface")
local State = require("StateMachine")
--require("debugger")
local leftCountN = 0
local rightCountN = 0
----------------------------------------------------------------------------------
--   State Machine
----------------------------------------------------------------------------------

stateMachine = State:create{
	initial = "randomWalk",
	substates = 
	{
		randomWalk = State:create{
			transMethod = function()
				local fromidS, cmdS, rxNumbersNT = getCMD()
				if cmdS == "recruit" then
					return "beingDriven"
				end
			end,
			initial = "straight",
			substates = {
				straight = State:create{
					enterMethod = function() goFront() end,
					transMethod = function()
						if objFront() == true then
							standStill()
							return "turn"
						end
						sideForward((math.random() - 0.5) * 5)
					end,
				}, 
				turn = State:create{
					enterMethod = function()
						if math.random() > 0.5 then turnLeft()
						                       else turnRight() end
					end,
					transMethod = function()
						if objFront() == false then
							return "straight"
						end
					end,
				},
			},
		}, -- end of randomWalk
		beingDriven = State:create{
			data = {countN = 0},
			enterMethod = function() setSpeed(0, 0) print(getSelfIDS(), ": I am recruited") end,
			transMethod = function(fdata, data, para)
				local fromidS, cmdS, rxNumbersNT = getCMD()
				if cmdS == 'push' then 
					setSpeed(rxNumbersNT[1], rxNumbersNT[2])
				else
					if (getProximityN(11) ~= 0 and cmdS ~= 'setaround') then
						if rightCountN ~= 0 then
							rightCountN = rightCountN -1
						else
							rightCountN = 10
						end
						setSpeed(1, 7)
						print('11')
					elseif (getProximityN(3) ~= 0 and cmdS ~= 'setaround') then
						if rightCountN ~= 0 then
							rightCountN = rightCountN -1
						else
							rightCountN = 10
						end
						setSpeed(7, 1)
						print('3')	
					elseif (getProximityN(1) ~= 0 and getProximityN(2) ~= 0) or leftCountN ~= 0 then
						if leftCountN ~= 0 then
							leftCountN = leftCountN -1
						else
							leftCountN = 10
						end
						setSpeed(5, 1)
						print('turn left')
						print(leftCountN)
					elseif (getProximityN(1) ~= 0 and getProximityN(12) ~= 0) or rightCountN ~= 0 then
						if rightCountN ~= 0 then
							rightCountN = rightCountN -1
						else
							rightCountN = 10
						end
						setSpeed(1, 5)
						print('turn right')
						print(rightCountN)
					elseif (getProximityN(1) ~= 0) then
						setSpeed(-2, 5)
					elseif cmdS == "setspeed"  then
						setSpeed(rxNumbersNT[1], rxNumbersNT[2])
					end
				end
				if cmdS == "dismiss" then
					print(getSelfIDS(), ": I am dismissed")
					return "randomWalk"
				end
				if fromidS ~= nil then
					sendCMD(fromidS, "sensor", getProximityTableNT())
					data.countN = 0
				else
					-- i didn't get command when I should be
					data.countN = data.countN + 1
					if data.countN > 3 then
						print(getSelfIDS(), ": I am lost")
						return "randomWalk"
					end
				end
			end,
		}, -- end of beingDriven
	} -- end of substates of stateMachine
} -- end of stateMachine

----------------------------------------------------------------------------------
--   ARGoS Functions
----------------------------------------------------------------------------------
function init()
	setTag(getSelfIDS())
	reset()
end

-------------------------------------------------------------------
function step()
	stateMachine:step()
end

-------------------------------------------------------------------
function reset()
	math.randomseed(1)
	-- TODO: get random seed from xml
end

-------------------------------------------------------------------
function destroy()
   -- put your code here
end

----------------------------------------------------------------------------------
--   Customize Functions
----------------------------------------------------------------------------------

local baseSpeedN = 10
function standStill()
	setSpeed(0, 0)
end
function goFront()
	setSpeed(baseSpeedN, baseSpeedN)
end
function turnLeft()
	setSpeed(-baseSpeedN, baseSpeedN)
end
function turnRight()
	setSpeed(baseSpeedN, -baseSpeedN)
end
function sideForward(x) -- 0 < x < 1
	setSpeed(baseSpeedN - baseSpeedN * x, baseSpeedN + baseSpeedN * x)
end

-------------------------------------------------------------------
function objFront()
	if getProximityN(1) ~= 0 or
	   getProximityN(2) ~= 0 or
	   getProximityN(12) ~= 0 then
		return true
	else
		return false
	end
end

-------------------------------------------------------------------
function getCMD()
	for i, rxBytesBT in pairs(getReceivedDataTableBT()) do	-- byte table
		local toIDS, fromIDS, cmdS, rxNumbersNT = bytesToTable(rxBytesBT)
		if toIDS == getSelfIDS() then
			return fromIDS, cmdS, rxNumbersNT
		end
	end
end

function sendCMD(toidS, cmdS, txDataNT)
	local txBytesBT = tableToBytes(toidS, 
	                               getSelfIDS(), 
                                   cmdS,
                                   txDataNT)
	transData(txBytesBT)
end

----------------------------------------------------------------------------------
--   Lua Interface
----------------------------------------------------------------------------------
function setSpeed(x,y)
	robot.joints.base_wheel_left.set_target(x)
	robot.joints.base_wheel_right.set_target(-y)
end

function getProximityN(x)
	return robot.proximity[x]
end

function getProximityTableNT()
	return robot.proximity
end

function transData(xBT)
	robot.radios["radio_0"].tx_data(xBT)
end

function getReceivedDataTableBT()	--BT means byte table
	return robot.radios["radio_0"].rx_data
end

function getSelfIDS()
	return robot.id
end

function setTag(str)
	robot.tags.set_all_payloads(str)
end
