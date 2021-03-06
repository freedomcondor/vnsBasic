----------------------------------------------------------------------------------
--   Global Variables
----------------------------------------------------------------------------------

require("PackageInterface")
--require("debugger")

local STATE = "recruiting"
local SON_VEHICLE_NAME = nil

----------------------------------------------------------------------------------
--   ARGoS Functions
----------------------------------------------------------------------------------
function init()
	reset()
end

-------------------------------------------------------------------
function step()
	-- detect boxes into boxesVT[i]
	local boxesVT = getBoxesVT()	
		-- V means vector = {x,y}

	-- detect robots into robotsRT[i] and robotsRT[id]
	local robotsRT = getRobotsRT()
		-- R for robot = {locV, dirN, idS}

	if STATE == "recruiting" then
		-- for each robot, if it has a box to move
		for i, vehicleR in ipairs(robotsRT) do
			local targetBoxV = getTargetBoxV(vehicleR.locV, boxesVT)
			if targetBoxV ~= nil then
				sendCMD(vehicleR.idS, "recruit")

				STATE = "driving"
				SON_VEHICLE_NAME = vehicleR.idS
				print(getSelfIDS(), ": i recruit vehicle", SON_VEHICLE_NAME)
				return -- return of step()
			end
		end
	elseif STATE == "driving" then
		local sonVehicle = robotsRT[SON_VEHICLE_NAME]
		if sonVehicle ~= nil then
			local targetBoxV = getTargetBoxV(sonVehicle.locV, boxesVT)

			if targetBoxV ~= nil then
				local boxDirtoRobotN = getBoxDirtoRobot(sonVehicle.locV, targetBoxV)
				local difN = boxDirtoRobotN - sonVehicle.dirN
				while difN > 180 do
					difN = difN - 360
				end
	
				while difN < -180 do
					difN = difN + 360
				end
				local baseSpeedN = 7
				if difN > 10 or difN < -10 then
					if (difN > 0) then
						setRobotVelocity(SON_VEHICLE_NAME, -baseSpeedN, baseSpeedN)
					else
						setRobotVelocity(SON_VEHICLE_NAME, baseSpeedN, -baseSpeedN)
					end
				else
					setRobotVelocity(SON_VEHICLE_NAME, baseSpeedN, baseSpeedN)
				end
			else
				-- no box to move, dismiss robot
				print(getSelfIDS(), ": i dismiss vehicle", SON_VEHICLE_NAME)
				sendCMD(sonVehicle.idS, "dismiss")
				STATE = "recruiting"
				SON_VEHICLE_NAME = nil
				return
			end
		else
			print(getSelfIDS(), ": i lost vehicle", SON_VEHICLE_NAME)
			STATE = "recruiting"
			SON_VEHICLE_NAME = nil
			return
			-- if I lost the robot (maybe the robot is out of range)
		end
	end 
end

-------------------------------------------------------------------
function reset()
end

-------------------------------------------------------------------
function destroy()
	-- put your code here
end

----------------------------------------------------------------------------------
--   Customize Functions
----------------------------------------------------------------------------------
function setRobotVelocity(id, x,y)
	local bytes = tableToBytes(id, robot.id , "setspeed", {x,y})
	robot.radios["radio_0"].tx_data(bytes)
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

-------------------------------------------------------------------
-- get boxes
-------------------------------------------------------------------
function getBoxesVT()
	local boxesVT = {}   -- vt for vector, which a table = {x,y}
	for i, detectionT in ipairs(getLEDsT()) do	
		-- a detection is a complicated table
		-- containing location and color information
		boxesVT[i] = getBoxPosition(detectionT)
	end	
	return boxesVT
end

function getBoxPosition (detection)
	local pos = {}
	pos.x = detection.center.x - 320
	pos.y = detection.center.y - 240
	pos.y = -pos.y 				-- make it left handed coordination system
	return pos
end

-------------------------------------------------------------------
-- get robots
-------------------------------------------------------------------
function getRobotsRT()
	robotsRT = {}
	for i, tagDetectionT in pairs(getTagsT()) do
		-- a tag detection is a complicated table
		-- containing center, corners, payloads
		
		-- get robot info
		local locV, dirN, idS = getRobotInfo(tagDetectionT)
			-- locV V for vector {x,y}
			-- loc (0,0) in the middle, x+ right, y+ up , 
			-- dir from 0 to 360, x+ as 0

		robotsRT[i] = {locV = locV, dirN = dirN, idS = idS}
		robotsRT[idS] = robotsRT[i]
	end
	return robotsRT
end

function getRobotInfo(tagT)
	-- a tag is a complicated table with center, corner, payload
	local degN = calcRobotDir(tagT.corners)
		-- a direction is a number from 0 to 360, 
		-- with 0 as the x+ axis of the quadcopter
		
	local locV = {}
	locV.x = tagT.center.x - 320
	locV.y = tagT.center.y - 240
	locV.y = -locV.y 				-- make it left handed coordination system

	local idS = tagT.payload

	return locV, degN, idS
end

-------------------------------------------------------------------
-- calculations
-------------------------------------------------------------------
function getTargetBoxV(robotLocV, boxesVT)
-- this function finds a box from boxes array for a robot to push based on:
-- if the box is outside the center zone (5000 length)
-- if the angle between the robot to the center (0,0)
--              and     the robot to the box
--        is small enough (cos >0.9)
-- if the box is towards inside not outside
-- then return the box location
-- if no such box, return nil
	local disR = robotLocV.x * robotLocV.x +
	             robotLocV.y * robotLocV.y
	for i, boxV in ipairs(boxesVT) do
		local disBoxtoCenterN = boxV.x * boxV.x + boxV.y * boxV.y
		if disBoxtoCenterN > 5000 then
			-- relative is the vector from robot to box
			local relativeV = {x = boxV.x - robotLocV.x,
			                   y = boxV.y - robotLocV.y,}
			local lRelN = math.sqrt(relativeV.x * relativeV.x +
			                        relativeV.y * relativeV.y )
			local lRobN = math.sqrt(robotLocV.x * robotLocV.x +
			                        robotLocV.y * robotLocV.y )
			local cosN = (-robotLocV.x * relativeV.x - robotLocV.y * relativeV.y) / 
			             lRelN / lRobN
			if cosN > 0.9 and lRobN > lRelN then
				return boxV
			end
		end
	end
	return nil
end

-------------------------------------------------------------------
function calcRobotDir(corners)
	-- a direction is a number from 0 to 360, 
	-- with 0 as the x+ axis of the quadcopter
	local front = {}
	front.x = (corners[3].x + corners[4].x) / 2
	front.y = -(corners[3].y + corners[4].y) / 2
	local back = {}
	back.x = (corners[1].x + corners[2].x) / 2
	back.y = -(corners[1].y + corners[2].y) / 2
	local deg = calcDir(back, front)
	return deg
end

-------------------------------------------------------------------
function getRobotHead(tag)
	-- a direction is a number from 0 to 360, 
	-- with 0 as the x+ axis of the quadcopter
	local pos = {}
	pos.x = ((tag.corners[3].x + tag.corners[4].x) / 2) - 320
	pos.y = ((tag.corners[3].y + tag.corners[4].y) / 2) - 240
	pos.y = -pos.y 				-- make it left handed coordination system
	return pos
end

-------------------------------------------------------------------
function getBoxDirtoRobot(robotPos, boxPos)
	-- a direction is a number from 0 to 360, 
	-- with 0 as the x+ axis of the quadcopter
	local deg = calcDir(robotPos, boxPos)
	return deg
end

-------------------------------------------------------------------
function calcDir(center, target)
	-- from center{x,y} to target{x,y} in left hand
	-- calculate a deg from 0 to 360, x+ is 0
	local x = target.x - center.x
	local y = target.y - center.y
	local deg = math.atan(y / x) * 180 / 3.1415926
	if x < 0 then
		deg = deg + 180
	end
	if deg < 0 then
		deg = deg + 360
	end
	return deg
end

----------------------------------------------------------------------------------
--   Lua Interface
----------------------------------------------------------------------------------
function setVelocity(x,y,theta)
	robot.joints.axis0_axis1.set_target(x)
	robot.joints.axis1_axis2.set_target(y)
	robot.joints.axis2_body.set_target(theta)
end

function getLEDsT()
	return robot.cameras.fixed_camera.led_detector
end

function getTagsT()
	return robot.cameras.fixed_camera.tag_detector
end

function transData(xBT)		--BT means byte table
	robot.radios["radio_0"].tx_data(xBT)
end

function getReceivedDataTableBT()
	return robot.radios["radio_0"].rx_data
end

function getSelfIDS()
	return robot.id
end
