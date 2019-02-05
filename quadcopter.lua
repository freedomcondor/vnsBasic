------------------------------------------------------------------------
--   Global Variables
------------------------------------------------------------------------
local STATE = "recruiting"
local CHILDNAME = nil

require("PackageInterface")
--require("debugger")

------------------------------------------------------------------------
--   ARGoS Functions
------------------------------------------------------------------------
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
		local targetRobotR = getTargetRobotandBox(robotsRT, boxesVT, 0.9)
		if targetRobotR ~= nil then
			sendCMD(targetRobotR.idS, "recruit")
			STATE = "driving"
			CHILDNAME = targetRobotR.idS
			return -- end this step
		end
	elseif STATE = "driving" then
		local childRobotR = robotsRT[CHILDNAME]
		if childRobotR == nil then
			-- if I lost the robot (maybe the robot is out of range)
			STATE = "recruiting"
			SON_VEHICLE_NAME = nil
			return
		else
			-- I have the vehicle, drive it towards the box
			local targetBoxV = getPushingBoxV(childRobotR.locV, boxesVT, 0.8)
			if targetBoxV == nil then
				-- i don't have a box to push
				sendCMD(childRobotR.idS, "dismiss")
				STATE = "recruiting"
				CHILDNAME = nil
			else
				-- drive
				local dirRobottoBoxN = calcDir(childRobotR.locV, targetBoxV)
				local difN = dirRobottoBoxN - childRobotR.dirN
				while difN > 180 do difN = difN - 360 end
				while difN < -180 do difN = difN + 360 end

				local baseSpeedN = 7
				if difN > 10 or difN < -10 then
					if (difN > 0) then
						setRobotVelocity(childRobotR.idS, -baseSpeedN, baseSpeedN)
					else
						setRobotVelocity(childRobotR.idS, baseSpeedN, -baseSpeedN)
					end
				else
					setRobotVelocity(childRobotR.idS, baseSpeedN, baseSpeedN)
				end
			end
		end
	elseif STATE = "turning" then
	end
	
	print("boxes:")
	for i, boxV in pairs(boxesVT) do
		print("\t", i, boxV.x, boxV.y)
	end

	print("robots:")
	for i, robotR in pairs(robotsRT) do
		print("\t", i, robotR.idS, robotR.locV.x, robotR.locV.y, robotR.dirN)
	end
end

-------------------------------------------------------------------
function reset()
end

-------------------------------------------------------------------
function destroy()
	-- put your code here
end

------------------------------------------------------------------------
--   Customize Functions
------------------------------------------------------------------------
function setRobotVelocity(id, x,y)
	sendCMD(id, "setspeed", {x, y})
end

-- calc ----------------------------------
function getTargetRobotandBox(robotsRT, boxesVT, thresholdN)
	local targetRobotR = nil
	local targetBoxV = nil
	local targetDisN = 999999999999 -- distance between robot to box
	for i, robotR in ipairs(robotsRT) do
		local boxV, disN = getPushingBoxV(robotR.locV, boxesVT, thresholdN)
		if disN < targetDisN then
			targetRobotR = robotR
			targetBoxV = boxV
			targetDisN = disN
		end
	end
	return targetRobotR, targetBoxV
end

function getPushingBoxV(robotLocV, boxesVT, thresholdN)
-- this function finds the nearest box from boxes array for a robot to push based on:
-- if the box is outside the center zone (5000 length)
-- if the angle between the robot to the center (0,0)
--              and     the robot to the box
--        is small enough (cos >0.9)
-- if the box is towards inside not outside
-- then return the box location
-- if no such box, return nil
	local targetBoxV = nil
	local targetDisN = 99999999999
	local disRobottoCenter = math.sqrt(robotLocV.x * robotLocV.x +
	                                   robotLocV.y * robotLocV.y )
	for i, boxV in ipairs(boxesVT) do
		local disBoxtoCenterN = boxV.x * boxV.x + boxV.y * boxV.y

		if disBoxtoCenterN > 5000 then -- else continue

		local vecRobottoBox = {x = boxV.x - robotLocV.x,
		                       y = boxV.y - robotLocV.y,}
		local disRobottoBox = math.sqrt(vecRobottoBox.x * vecRobottoBox.x +
			                                vecRobottoBox.y * vecRobottoBox.y )

		if disRobottoBox < targetDisN then -- else continue

		local cosN = (-robotLocV.x * vecRobottoBox.x - robotLocV.y * vecRobottoBox.y) / 
		             (disRobottoBox * disRobottoCenter)

		--if cosN > 0.9 and disRobottoCenter > disRobottoBox then -- else continue
		if cosN > thresholdN and disRobottoCenter > disRobottoBox then -- else continue

		targetBoxV = boxV
		targetDisN = disRobottoBox
		end end end
	end
	return targetBoxV, targetDisN
end

-- see boxes and robots ------------------
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
