------------------------------------------------------------------------
--   Global Variables
------------------------------------------------------------------------

require("PackageInterface")
--require("debugger")

local STATE = {}
	-- STATE[robotName] = "recruit", "drive" ... 
local LAST_ROBOTS = {}
local CURRENT_ROBOTS = {}

local parentQuacopter = nil

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
		-- R for robot = {locV, dirN, idS, parent}

	-- receive robots from other quadcopter
	local cmdListCT = getCMDListCT()  
		-- CT means CMD Table(array)
		-- a cmd contains: {cmdS, fromIDS, dataNST}
	for i, cmdC in ipairs(cmdListCT) do
		if cmdC.cmdS == "VisionInfo" then
			setVelocity(0, 0, 0)
			local receivedRobotsRT, receivedBoxesVT = 
				bindVisionInfoDataRT(cmdC.dataNST)

			--robotsRT, boxesVT, transParaIndex[cmdC.fromIDS] = 
			robotsRT, boxesVT = 
				joinReceivedVisionRTVTT(robotsRT, boxesVT, receivedRobotsRT, receivedBoxesVT)
		end
	end

	--[[
	print("boxes:")
	for i, boxV in pairs(boxesVT) do
		print("\t", i, boxV.x, boxV.y)
	end

	print("robots:")
	for i, robotR in pairs(robotsRT) do
		print("\t", i, robotR.idS, robotR.locV.x, robotR.locV.y, robotR.dirN)
	end
	--]]

	-- check deny
	for i, cmdC in ipairs(cmdListCT) do
		if cmdC.cmdS == "deny" then
			STATE[cmdC.fromIDS] = nil
			-- TODO: dismiss every vehicle
			parentQuacopter = cmdC.dataNST[1]
		end
	end

	if parentQuacopter ~= nil then
		-- send robots to parent quadcopter 
		local VisionDataNST = makeVisionInfoDataNST(robotsRT, boxesVT) -- NST means a table of number or string
		sendCMD(parentQuacopter, "VisionInfo", VisionDataNST)
		setVelocity(0, 0, 0)
		return -- return step
	end
	-- else I am a brain

	-- fly randomly
	--if getSelfIDS() ~= "quadcopter0" then
		local turn = (math.random() - 0.5) * 20
		local speedN = 0.05
		setVelocity(speedN, 0, turn)
	--end
	
	for i, robotR in ipairs(robotsRT) do
		-- record vehicle for next step
		-- LAST_ROBOTS to find out who was in last step but not in current step
		LAST_ROBOTS[robotR.idS] = nil
		CURRENT_ROBOTS[robotR.idS] = true

		if STATE[robotR.idS] == nil then
			-- new robot
			STATE[robotR.idS] = "recruiting"
		end
		if STATE[robotR.idS] == "recruiting" then
			sendCMD(robotR.idS, "recruit", {math.random()})
			STATE[robotR.idS] = "driving"
		elseif STATE[robotR.idS] == "driving" then
			-- drive
			local dirRobottoCenterN = calcDir(robotR.locV, {x = 0, y = 0})
			local disRobottoCenterN = math.sqrt(robotR.locV.x * robotR.locV.x + 
			                                    robotR.locV.y * robotR.locV.y)
			local difN = dirRobottoCenterN - robotR.dirN
			while difN > 180 do difN = difN - 360 end
			while difN < -180 do difN = difN + 360 end

			if disRobottoCenterN > 10 then
				local baseSpeedN = 20
				if difN > 10 or difN < -10 then
					if (difN > 0) then
						setRobotVelocity(robotR.idS, 0, baseSpeedN)
					else
						setRobotVelocity(robotR.idS, baseSpeedN, 0)
					end
				else
					setRobotVelocity(robotR.idS, baseSpeedN, baseSpeedN)
				end
			else
				setRobotVelocity(robotR.idS, 0, 0)
			end
		elseif STATE[robotR.idS] == "turning" then
			--[[
			local targetBoxV, _, targetDirS = getPushingBoxV(robotR.locV, boxesVT, 100, 0.9)
			if targetBoxV == nil and targetDirS == nil then
				-- i don't have a box to push
				sendCMD(robotR.idS, "dismiss")
				STATE[robotR.idS] = "recruiting"
			elseif targetBoxV == nil and targetDirS ~= nil then
				-- target box is still out of angle, keep turning
				sendCMD(robotR.idS, "keepgoing")
			elseif targetBoxV ~= nil then
				sendCMD(robotR.idS, "beingDriven")
				STATE[robotR.idS] = "driving"
			end
			--]]
		end
	end
	
	-- find untracked vehicle
	for i, v in pairs(LAST_ROBOTS) do
		STATE[i] = nil
	end
	LAST_ROBOTS = CURRENT_ROBOTS
	CURRENT_ROBOTS = {}
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
function getTargetRobotandBox(robotsRT, boxesVT, disThreshold, angleThresholdN)
	local targetRobotR = nil
	local targetBoxV = nil
	local targetDisN = disThreshold -- distance between robot to box
	for i, robotR in ipairs(robotsRT) do
		local boxV, disN = getPushingBoxV(robotR.locV, boxesVT,  disThreshold, angleThresholdN)
		if boxV ~= nil and disN < targetDisN then
			targetRobotR = robotR
			targetBoxV = boxV
			targetDisN = disN
		end
	end
	return targetRobotR, targetBoxV
end

function getPushingBoxV(robotLocV, boxesVT, disThresholdN, angleThresholdN)
-- this function finds the nearest box from boxes array for a robot to push based on:
-- if the box is outside the center zone (70 length)
-- if the angle between the robot to the center (0,0)
--              and     the robot to the box
--        is small enough (cos > angleThreshold)
-- if the box is towards inside not outside
-- then return the box location
-- if no such box, return nil
	local targetBoxV = nil
	local targetDisN = disThresholdN -- distance between robot to box
		-- can also serve a threshold
	local targetDirS = nil
	local disRobottoCenterN = math.sqrt(robotLocV.x * robotLocV.x +
	                                   robotLocV.y * robotLocV.y )
	for i, boxV in ipairs(boxesVT) do
		local disBoxtoCenterN = math.sqrt(boxV.x * boxV.x + boxV.y * boxV.y)

		if disBoxtoCenterN > 70 then -- else continue 
			-- find all the outsider box
		if disRobottoCenterN > disBoxtoCenterN then -- else continue 
			-- robot is outside of the box

		local vecRobottoBoxV = {x = boxV.x - robotLocV.x,
		                        y = boxV.y - robotLocV.y,}
		local disRobottoBoxN = math.sqrt(vecRobottoBoxV.x * vecRobottoBoxV.x +
		                                 vecRobottoBoxV.y * vecRobottoBoxV.y )

		if disRobottoBoxN < targetDisN then -- else continue -- find the nearest one

		local cosN = (-robotLocV.x * vecRobottoBoxV.x - robotLocV.y * vecRobottoBoxV.y) / 
		             (disRobottoBoxN * disRobottoCenterN)

		if cosN > angleThresholdN then -- else continue
			targetBoxV = boxV
			targetDisN = disRobottoBoxN
		else
			-- check box is to the left or right
			local y = (-vecRobottoBoxV.x * (-robotLocV.y) + vecRobottoBoxV.y * (-robotLocV.x))
			if y > 0 then targetDirS = "left"
			         else targetDirS = "right" end
		end end end end
	end
	return targetBoxV, targetDisN, targetDirS
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
	local robotsRT = {}
	for i, tagDetectionT in pairs(getTagsT()) do
		-- a tag detection is a complicated table
		-- containing center, corners, payloads
		
		-- get robot info
		local locV, dirN, idS = getRobotInfo(tagDetectionT)
			-- locV V for vector {x,y}
			-- loc (0,0) in the middle, x+ right, y+ up , 
			-- dir from 0 to 360, x+ as 0

		robotsRT[i] = {locV = locV, dirN = dirN, idS = idS, parent = getSelfIDS()}
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

---------- shared vision ----------------------
function makeVisionInfoDataNST(robotsRT, boxesVT)
	-- robotsRT is a table of {locV, dirN, idS}
	local dataNST = {}
	dataNST[1] = #robotsRT	-- a table of number or String
	local i = 2
	for _, v in ipairs(robotsRT) do
		dataNST[i] = v.idS
		dataNST[i+1] = v.locV.x
		dataNST[i+2] = v.locV.y
		dataNST[i+3] = v.dirN
		dataNST[i+4] = v.parent
		i = i + 5
	end

	dataNST[i] = #boxesVT
	i = i + 1
	for _, v in ipairs(boxesVT) do
		dataNST[i] = v.x
		dataNST[i+1] = v.y
		i = i + 2
	end
	return dataNST
end

function bindVisionInfoDataRT(dataNST)
	local n = dataNST[1]
	local i = 2
	local robotsRT = {}
	for j = 1, n do
		robotsRT[j] = {}
		robotsRT[j].idS = dataNST[i]
		robotsRT[j].locV = {x = dataNST[i+1],
		                    y = dataNST[i+2]}
		robotsRT[j].dirN = dataNST[i+3]
		robotsRT[j].parent = dataNST[i+4]
		i = i + 5
	end

	n = dataNST[i]
	i = i + 1
	local boxesVT = {}
	for j = 1, n do
		boxesVT[j] = {}
		boxesVT[j].x = dataNST[i]
		boxesVT[j].y = dataNST[i+1]
		i = i + 2
	end
	return robotsRT, boxesVT
end

function joinReceivedVisionRTVTT(robotsRT, boxesVT, receivedRobotsRT, receivedBoxesVT)
	-- find a common robot
	local paraT = {} -- rotation and translation parameters
	for i, vR in ipairs(receivedRobotsRT) do
		if robotsRT[vR.idS] ~= nil then
			local thN = robotsRT[vR.idS].dirN - vR.dirN
			local thRadN = thN * math.pi / 180
			paraT.x = vR.locV.x * math.cos(thRadN) - 
			          vR.locV.y * math.sin(thRadN)
			paraT.y = vR.locV.x * math.sin(thRadN) + 
			          vR.locV.y * math.cos(thRadN)
				-- new location of received after rotation
			paraT.x = robotsRT[vR.idS].locV.x - paraT.x
			paraT.y = robotsRT[vR.idS].locV.y - paraT.y
				-- translation vector
			paraT.thN = thN

			--break?
		end
	end

	if paraT.thN == nil then
		print("no overlapping robot, can't join")
	else
		local thN = paraT.thN
		local thRadN = thN * math.pi / 180
		---- join robots
		local nRobots = #robotsRT
		for i, vR in ipairs(receivedRobotsRT) do
			-- calc and add into robotsRT
			if robotsRT[vR.idS] == nil then
				nRobots = nRobots + 1
				robotsRT[nRobots] = {}
				robotsRT[nRobots].locV = {
					x = vR.locV.x * math.cos(thRadN) - 
					    vR.locV.y * math.sin(thRadN) + paraT.x,
					y = vR.locV.x * math.sin(thRadN) + 
					    vR.locV.y * math.cos(thRadN) + paraT.y,
				}
				robotsRT[nRobots].idS = vR.idS
				robotsRT[nRobots].parent = vR.parent
				robotsRT[nRobots].dirN = (vR.dirN + thN) % 360  
					-- it should still be inside range [0,360]
				robotsRT[vR.idS] = robotsRT[nRobots]
			end
		end
		---- join boxes
		local nBoxes = #boxesVT
		for i, receivedBoxV in ipairs(receivedBoxesVT) do
			local transferedV = {
				x = receivedBoxV.x * math.cos(thRadN) - 
				    receivedBoxV.y * math.sin(thRadN) + paraT.x,
				y = receivedBoxV.x * math.sin(thRadN) + 
				    receivedBoxV.y * math.cos(thRadN) + paraT.y,
			}

			-- check same box
			local flag = 0
			for j, boxV in ipairs(boxesVT) do
				local x = boxV.x - transferedV.x
				local y = boxV.y - transferedV.y
				local disN = math.sqrt(x * x + y * y)
				if disN < 15 then -- else continue
					flag = 1
					break
				end
			end
			if flag == 0 then
				nBoxes = nBoxes + 1
				boxesVT[nBoxes] = transferedV
			end
		end
	end
	return robotsRT, boxesVT, paraT
end

----------------------------------------------------------------------------------
--   Lua Interface
----------------------------------------------------------------------------------
function setVelocity(x,y,theta)	
	--quadcopter heading is the x+ axis
	local thRad = robot.joints.axis2_body.encoder
	local xWorld = x * math.cos(thRad) - y * math.sin(thRad)
	local yWorld = x * math.sin(thRad) + y * math.cos(thRad)
	robot.joints.axis0_axis1.set_target(xWorld)
	robot.joints.axis1_axis2.set_target(yWorld)
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
