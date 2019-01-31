----------------------------------------------------------------------------------
--   Global Variables
----------------------------------------------------------------------------------

require("PackageInterface")
local State = require("StateMachine")
--require("debugger")

----------------------------------------------------------------------------------
--   State Machine
----------------------------------------------------------------------------------

stateMachine = State:create{
	data = {turnBySelfDir = nil},
	initial = "randomWalk",
	substates = 
	{
		randomWalk = State:create{
			transMethod = function(fdata, data, para)
				local fromidS, cmdS, rxNumbersNT = getCMD()
				if cmdS == "recruit" then
					return "beingDriven"
				end

				if objFront() == true then
					if math.random() > 0.5 then fdata.turnBySelfDir = "left"
					                       else fdata.turnBySelfDir = "right" end
					return "turnBySelf"
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
				if cmdS == "setspeed" then
					setSpeed(rxNumbersNT[1], rxNumbersNT[2])
				end
				if cmdS == "dismiss" then
					print(getSelfIDS(), ": I am dismissed")
					return "randomWalk"
				end
				if cmdS == "turn" then
					if rxNumbersNT[1] == 1 then
						fdata.turnBySelfDir = "left"
					else
						fdata.turnBySelfDir = "right"
					end
					return "turnBySelf"
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
		turnBySelf = State:create{
			data = {turnBySelfDir = nil},
			enterMethod = function(fdata, data, para)
				print(getSelfIDS(), "i am turnBySelf", fdata.turnBySelfDir)
				data.turnBySelfDir = fdata.turnBySelfDir
			end,
			transMethod = function()
				if objFront() == false then goFront() end 
					-- make it walk along the box in the future
					
				local fromidS, cmdS, rxNumbersNT = getCMD()
				if cmdS == "setspeed" then
					setSpeed(rxNumbersNT[1], rxNumbersNT[2])
					return "beingDriven"
				end
				if cmdS == "dismiss" then
					print(getSelfIDS(), ": I am dismissed")
					return "randomWalk"
				end
			end,
			initial = "turn",
			substates = {
				turn = State:create{
					enterMethod = function(fdata, data, para)
						if fdata.turnBySelfDir == "left" then turnLeft()
						                                 else turnRight() end
					end,
					transMethod = function()
						if objFront() == false then return "walkAlong" end 
					end,
				},
				walkAlong = State:create{
					enterMethod = function() goFront() end,
					transMethod = function(fdata, data, para)
						--[[ it doesn't work
						local testFunc, turnFunc
						if fdata.turnBySelfDir == "left" then testFunc = objNearRight
						                                      turnFunc = turnFrontRight
						                                 else testFunc = objNearLeft 
						                                      turnFunc = turnFrontLeft end
						if testFunc() == false then turnFunc()
						                       else goFront() end
						--]]
					end,
				},
			}, -- end of substates of turnBySelf
		}, -- end of turnBySelf
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
function turnFrontLeft()
	setSpeed(0, baseSpeedN)
end
function turnRight()
	setSpeed(baseSpeedN, -baseSpeedN)
end
function turnFrontRight()
	setSpeed(baseSpeedN, 0)
end
function sideForward(x) -- 0 < x < 1
	setSpeed(baseSpeedN - baseSpeedN * x, baseSpeedN + baseSpeedN * x)
end

-------------------------------------------------------------------
-- Proximity sensors:  1 in front, 4 left, 7 back, 10 right
function objFront()
	if getProximityN(1) ~= 0 or
	   getProximityN(2) ~= 0 or
	   getProximityN(12) ~= 0 then
		return true
	else
		return false
	end
end

function objNearLeft()
	if getProximityN(3) ~= 0 and
	   getProximityN(4) ~= 0 and
	   getProximityN(5) ~= 0 then return true
	                         else return false end
end

function objFarLeft()
	if getProximityN(4) ~= 0 then return true
	                         else return false end
end

function objNearRight()
	if getProximityN(10) ~= 0 then return true
	                          else return false end
end

function objFarRight()
	if getProximityN(9) ~= 0 or
	   getProximityN(10) ~= 0 or
	   getProximityN(11) ~= 0 then return true
	                          else return false end
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
