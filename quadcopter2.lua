----------------------------------------------------------------------------------
--   Global Variables
----------------------------------------------------------------------------------

require("PackageInterface")
local Vec3 = require("math/Vector3")

--require("debugger")

local sonRobots = {} -- recruitedVehicles["iamid"] = true

----------------------------------------------------------------------------------
--   ARGoS Functions
----------------------------------------------------------------------------------
function init()
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
	
	-------  qudcopter1 ----------
	if getSelfIDS() == "quadcopter1" then
		setVelocity(0,0,1)

		local robotsDataNST = makeRobotInfoDataNST(robotsRT) -- NST means a table of number/string
		sendCMD("quadcopter0", "robotsInfo", robotsDataNST)

		---[[
		print("i am 1, I got:")
		for i, v in ipairs(robotsRT) do
			print("\t", i, v.idS, v.locV.x, v.locV.y, v.dirN)
		end
		--]]
	end

	-------  qudcopter0 ----------
	if getSelfIDS() == "quadcopter0" then
		local fromIDS, cmdS, rxNumbersNT = getCMD()
		if fromIDS == "quadcopter1" and cmdS == "robotsInfo" then
			local receivedRobotsRT = bindRobotInfoDataRT(rxNumbersNT)

			robotsRT = joinReceivedRobotsRT(robotsRT, receivedRobotsRT)

		---[[
		print("I am 0, I got:")
		for i, v in ipairs(robotsRT) do
			print("\t", i, v.idS, v.locV.x, v.locV.y, v.dirN)
		end
		--]]
		
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

function makeRobotInfoDataNST(robotsRT)
	-- robotsRT is a table of {locV, dirN, idS}
	local dataNST = {}
	dataNST[1] = #robotsRT	-- a table of number or String
	local i = 2
	for _, v in ipairs(robotsRT) do
		dataNST[i] = v.idS
		dataNST[i+1] = v.locV.x
		dataNST[i+2] = v.locV.y
		dataNST[i+3] = v.dirN
		i = i + 4
	end
	return dataNST
end

function bindRobotInfoDataRT(dataNST)
	local n = dataNST[1]
	local robotsRT = {}
	local i = 2
	for j = 1, n do
		robotsRT[j] = {}
		robotsRT[j].idS = dataNST[i]
		robotsRT[j].locV = {x = dataNST[i+1],
		                    y = dataNST[i+2]}
		robotsRT[j].dirN = dataNST[i+3]
		i = i + 4
	end
	return robotsRT
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

--------------------------------------------------------------------
function joinReceivedRobotsRT(robotsRT, receivedRobotsRT)
	local paraT = {} -- rotation and translation parameters
	for i, vR in ipairs(receivedRobotsRT) do
		if robotsRT[vR.idS] ~= nil then
			local thN = robotsRT[vR.idS].dirN - vR.dirN
			local thRadN = thN * math.pi / 180
			paraT.x = vR.locV.x * math.cos(thRadN) - vR.locV.y * math.sin(thRadN)
			paraT.y = vR.locV.x * math.sin(thRadN) + vR.locV.y * math.cos(thRadN)
				-- new location of received after rotation
			paraT.x = robotsRT[vR.idS].locV.x - paraT.x
			paraT.y = robotsRT[vR.idS].locV.y - paraT.y
				-- translation vector
			paraT.thN = thN
		end
	end

	if paraT.thN == nil then
		print("no overlapping robot, can't join")
	else
		local thN = paraT.thN
		local thRadN = thN * math.pi / 180
		local nRobots = #robotsRT
		for i, vR in ipairs(receivedRobotsRT) do
			-- calc and add into robotsRT
			if robotsRT[vR.idS] == nil then
				nRobots = nRobots + 1
				robotsRT[nRobots] = {}
				robotsRT[nRobots].locV = {
					x = vR.locV.x * math.cos(thRadN) - vR.locV.y * math.sin(thRadN) + paraT.x,
					y = vR.locV.x * math.sin(thRadN) + vR.locV.y * math.cos(thRadN) + paraT.y,
				}
				robotsRT[nRobots].idS = vR.idS
				robotsRT[nRobots].dirN = (vR.dirN + thN) % 360  -- it should still be inside range [0,360]
				robotsRT[vR.idS] = robotsRT[nRobots]
			end
		end
	end
	return robotsRT
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