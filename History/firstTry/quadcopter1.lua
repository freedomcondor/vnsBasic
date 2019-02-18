----------------------------------------------------------------------------------
--   Global Variables
----------------------------------------------------------------------------------

require("PackageInterface")
require("debugger")
Vec3 = require("math/Vector3")

local sonRobots = {} -- recruitedVehicles["iamid"] = true

----------------------------------------------------------------------------------
--   ARGoS Functions
----------------------------------------------------------------------------------
function init()
	math.randomseed(1)
	reset()
end

-------------------------------------------------------------------
function step()
	-- detect boxes into boxesVT[i]
	-- local boxPos_vt = getBoxesVT()	
	local boxesVT = getBoxesVT()	
		-- V means vector = {x,y}

	-- detect robots into robotsRT[i] and robotsRT[id]
	local robotsRT = getRobotsRT()
		-- R for robot = {locV, dirN, idS}

	-- get cmd, check deny
	-- TODO:
	
	for i, vehicleR in ipairs(robotsRT) do
		if sonRobots[vehicleR.idS] == nil then
			-- a free vehicle
			local targetBoxV = getTargetBoxV(vehicleR.locV, boxesVT)
			if targetBoxV ~= nil then
				sendCMD(vehicleR.idS, "recruit")
				sonRobots[vehicleR.idS] = true
				print(getSelfIDS(), ": i recruit vehicle", vehicleR.idS)
			end
		else
			-- a holding vehicle
			local targetBoxV, boxDir = getTargetBoxV(vehicleR.locV, boxesVT)
			if targetBoxV ~= nil then
				local boxDirtoRobotN = getBoxDirtoRobot(vehicleR.locV, targetBoxV)
				local centerDirtoRobotN = getBoxDirtoRobot(vehicleR.locV, {x=0,y=0})

				-- calc the box is left or right to the robot it self
				local difN = boxDirtoRobotN - vehicleR.dirN
				while difN > 180 do
					difN = difN - 360
				end
	
				while difN < -180 do
					difN = difN + 360
				end
				local baseSpeedN = 7
				if difN > 10 or difN < -10 then
					if (difN > 0) then
						setRobotVelocity(vehicleR.idS, -baseSpeedN, baseSpeedN)
					else
						setRobotVelocity(vehicleR.idS, baseSpeedN, -baseSpeedN)
					end
				else
					setRobotVelocity(vehicleR.idS, baseSpeedN, baseSpeedN)
				end
			else
				-- no box to move, 
				if boxDir == nil then
					-- box in position, dismiss robot
					print(getSelfIDS(), ": i dismiss vehicle", vehicleR.idS)
					sendCMD(vehicleR.idS, "dismiss")
					sonRobots[vehicleR.idS] = nil
				else
					print("I send a turn cmd")
					sendCMD(vehicleR.idS, "turn", boxDir) -- boxDir is 1(left) or 2(right)
				end
			end
		end -- end of if sonRobots
	end -- end of for vehicle
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
				print(i,"box out and with right direction")
				return boxV, nil
			end
		else
			print(i,"box in position")
			return nil, nil
		end
	end
	for i, boxV in ipairs(boxesVT) do
		-- relative is the vector from robot to box
		local relativeV = {x = boxV.x - robotLocV.x,
		                   y = boxV.y - robotLocV.y,}
		local lRelN = math.sqrt(relativeV.x * relativeV.x +
		                        relativeV.y * relativeV.y )
		local relativeV3 = Vec3:create(relativeV.x, relativeV.y, 0)
		local centerV3 = Vec3:create(-robotLocV.x, -robotLocV.y, 0)
		local dirV3 = relativeV3 * centerV3
		local dirN = 1
		if dirV3.z > 0 then -- box is on the right
			dirN = 2
		end
		if lRelN < 50 then
			print(i,"test1")
			return nil, dirN	-- TODO: check left or right
		end
	end
	print(i,"test2")
	return nil, nil
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
