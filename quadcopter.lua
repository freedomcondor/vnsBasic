------------------------------------------------------------------------
--   Global Variables
------------------------------------------------------------------------

package.path = package.path .. ";math/?.lua"
require("PackageInterface")
local State = require("StateMachine")
local Vec3 = require("math/Vector3")
local Quaternion = require("math/Quaternion")
local VNS = require("VNS")
--require("debugger")

local vns

------------------------------------------------------------------------
--   ARGoS Functions
------------------------------------------------------------------------
function init()
	reset()
end

-------------------------------------------------------------------
function reset()
	vns = VNS:new{
		id = getSelfIDS(),
		typeS = "quadcopter",
		stateS = "wandering",
	}
	vns.childrenRolesVnsTT.marking = {}
	vns.childrenRolesVnsTT.driving = {}
	vns.childrenRolesVnsTT.quads = {}
	vns.childrenRolesVnsTT.waitingAnswer= {}
	vns.childrenRolesVnsTT.deny = {}
end

-------------------------------------------------------------------
function step()
-- see the world -------------------------------------

	local robotsRT = getRobotsRT()
		-- R for robot = {locV, dirN, idS, parent}
	local boxesVT = getBoxesVT()	
		-- V means vector = {x,y}

-- hear about the world ------------------------------

	local quadsQT = {}
	local hearingBoxesVT = {}
	local hearingRobotsRT = {}
	-- receive robots from other quadcopter
	local cmdListCT = getCMDListCT()  
		-- CT means CMD Table(array)
		-- a cmd contains: {cmdS, fromIDS, dataNST}
	for i, cmdC in ipairs(cmdListCT) do
		if cmdC.cmdS == "VisionInfo" then
			local receivedRobotsRT, receivedBoxesVT = 
				bindVisionInfoDataRT(cmdC.dataNST)

			local reportingQuadQ = calcQuadQ(cmdC.fromIDS, robotsRT, receivedRobotsRT)
				-- Q = {locV, dirN, idS, markidS}

			if reportingQuadQ ~= nil then -- else continue
		
			calcCoor(receivedRobotsRT, receivedBoxesVT, reportingQuadQ)

			local n = #quadsQT + 1
			quadsQT[n] = reportingQuadQ
			quadsQT[reportingQuadQ.idS] = reportingQuadQ

			hearingRobotsRT = joinRobots(hearingRobotsRT, receivedRobotsRT)
			hearingBoxesVT = joinBoxes(hearingBoxesVT, receivedBoxesVT)
		end end
	end
-- get boxesVT, 
--     robotsRT, 
--     quadsQT, 
--     hearingBoxesVT, 
--     hearingRobotsRT

local rallyPointV = {x = 0, y = 0}
-- cmd from parent -------------------------------------
	if vns.stateS == "wandering" then
	-- fly randomly
		local turn = (math.random() - 0.5) * 3
		local speedLN = (math.random() - 0.5) * 0.50
		local speedRN = (math.random() - 0.5) * 0.50
		local speedN = math.sqrt(speedLN * speedLN + speedRN * speedRN)
		speedLN = speedLN / speedN
		speedRN = speedRN / speedN
		setVelocity(speedLN, speedRN, turn)
	elseif vns.stateS == "reporting" then
		local cmdListCT = getCMDListCT(vns.parentS)  
		print(#cmdListCT)
		for i, cmdC in ipairs(cmdListCT) do
			if cmdC.cmdS == "fly" then
				print("i received fly")
				print(cmdC.dataNST[1])
				print(cmdC.dataNST[2])
				print(cmdC.dataNST[3])
				print(cmdC.dataNST[4])
				print(cmdC.dataNST[5])
				rallyPointV = {
					x = cmdC.dataNST[1],
					y = cmdC.dataNST[2],
				}
				local rotateN = cmdC.dataNST[5]
				if cmdC.dataNST[5] > 5 then
					rotateN = 5
				elseif cmdC.dataNST[5] < -5 then
					rotateN = -5
				end

				setVelocity(cmdC.dataNST[3], cmdC.dataNST[4], rotateN)
			end
		end

		local VisionDataNST = makeVisionInfoDataNST(robotsRT, boxesVT) 
		sendCMD(vns.parentS, "VisionInfo", VisionDataNST)

	elseif vns.stateS == "braining" then
		setVelocity(0, 0, 0)
	end

-- be recruited --------------------------------
	if vns.stateS == "wandering" then
		local cmdListCT = getCMDListCT()  
		for i, cmdC in ipairs(cmdListCT) do
			if cmdC.cmdS == "recruit" then
				vns.stateS = "reporting"
				vns.parentS = cmdC.fromIDS
				print("i am recruited, parent:", vns.parentS)
			end
		end
	end

-- recruit new quads -----------------------------
	if vns.stateS == "wandering" or vns.stateS == "braining" then
		for i, quadQ in ipairs(quadsQT) do
			if vns.childrenVnsT[quadQ.idS] == nil then
				sendCMD(quadQ.idS, "recruit", {math.random()})
				local vVns = VNS:new{
					idS = quadQ.idS, locV = quadQ.locV, 
					dirN = quadQ.dirN, typeS = "quad", 
				}
				vns:add(vVns, "waitingAnswer")
			end
		end
	end
	
	if vns.stateS == "wandering" and #quadsQT ~= 0 then
		vns.stateS = "braining"
		print(getSelfIDS(), "i become a brain")
	end

-- update vns, remove lost ones, remove denied ones --------------
	local denyParent = {}
	for idS, childVns in pairs(vns.childrenVnsT) do
		if robotsRT[idS] ~= nil then
			childVns.locV = robotsRT[idS].locV
			childVns.dirN = robotsRT[idS].dirN
		elseif quadsQT[idS] ~= nil then
			childVns.locV = quadsQT[idS].locV
			childVns.dirN = quadsQT[idS].dirN
			childVns.markidS = quadsQT[idS].markidS
		else
			-- can't see this child anymore
			vns:remove(idS)
		end

		-- check deny
		local cmdListCT = getCMDListCT(idS)  
		local flag = 0
		for i, cmdC in ipairs(cmdListCT) do
			if cmdC.cmdS == "deny" then
				vns:changeRole(idS, "deny")
				denyParent[idS] = cmdC.dataNST[1]
				flag = 1 
				break 
			end 
		end

		-- reinforce marking from driving
		local markingNumberN = 4
		if vns.stateS == "reporting" then markingNumberN = 2 end
		if table.getSize(vns.childrenRolesVnsTT.marking) < markingNumberN then
			for idS, childRQ in pairs(vns.childrenRolesVnsTT.driving) do
				vns:changeRole(idS, "marking")
				break
			end
		end
		if table.getSize(vns.childrenRolesVnsTT.marking) > markingNumberN then
			for idS, childRQ in pairs(vns.childrenRolesVnsTT.marking) do
				vns:changeRole(idS, "driving")
				break
			end
		end
	end

	-- denied
	if vns.stateS == "wandering" then
		for idS, robotR in pairs(vns.childrenRolesVnsTT.deny) do
			local parentidS = denyParent[idS]
			local VisionDataNST = makeVisionInfoDataNST(robotsRT, boxesVT) 
				-- NST means a table of number or string
			sendCMD(parentidS, "VisionInfo", VisionDataNST)
			break
		end
	end
	for idS, robotR in pairs(vns.childrenRolesVnsTT.deny) do
		vns:remove(idS)
	end

-- allocate answering robots ---------------------
	for idS, childRQ in pairs(vns.childrenRolesVnsTT.waitingAnswer) do
		if childRQ.typeS == "robot" then
			local markingNumberN = 4
			if vns.stateS == "reporting" then markingNumberN = 2 end
			if table.getSize(vns.childrenRolesVnsTT.marking) < markingNumberN then
				vns:changeRole(idS, "marking")
			else
				vns:changeRole(idS, "driving")
			end
		elseif childRQ.typeS == "quad" then
			--if table.getSize(vns.childrenRolesVnsTT.quads) < 4 then
				vns:changeRole(idS, "quads")
			--end
		end
	end

-- drive robots ----------------------------------
	-- marking robots
	for idS, robotR in pairs(vns.childrenRolesVnsTT.marking) do
		local fluxVectorV = calcFlux(robotR.locV, vns.childrenRolesVnsTT.marking, vns.stateS)
		local disFluxN = math.sqrt(fluxVectorV.x * fluxVectorV.x + 
		                           fluxVectorV.y * fluxVectorV.y)
		fluxVectorV.x = fluxVectorV.x + robotR.locV.x
		fluxVectorV.y = fluxVectorV.y + robotR.locV.y
		local dirRobottoTargetN = calcDir(robotR.locV, fluxVectorV)

		local difN = dirRobottoTargetN - robotR.dirN
		while difN > 180 do difN = difN - 360 end
		while difN < -180 do difN = difN + 360 end
		local baseSpeedN = 10
		if difN > 20 or difN < -20 then
			if (difN > 0) then
				setRobotVelocity(robotR.idS, -baseSpeedN/2, baseSpeedN)
			else
				setRobotVelocity(robotR.idS, baseSpeedN, -baseSpeedN/2)
			end
		else
			setRobotVelocity(robotR.idS, baseSpeedN * 4, baseSpeedN * 4)
		end
	end

	-- driving robots
	for idS, robotR in pairs(vns.childrenRolesVnsTT.driving) do
		--local vecRobotToCenterV = {x = rallyPointV.x - robotR.locV.x, 
		--                           y = rallyPointV.y - robotR.locV.y}
		local dirRobottoTargetN = calcDir(robotR.locV, rallyPointV)

		local difN = dirRobottoTargetN - robotR.dirN
		while difN > 180 do difN = difN - 360 end
		while difN < -180 do difN = difN + 360 end
		local baseSpeedN = 10
		if difN > 20 or difN < -20 then
			if (difN > 0) then
				setRobotVelocity(robotR.idS, -baseSpeedN/2, baseSpeedN)
			else
				setRobotVelocity(robotR.idS, baseSpeedN, -baseSpeedN/2)
			end
		else
			setRobotVelocity(robotR.idS, baseSpeedN * 4, baseSpeedN * 4)
		end

	end

	-- quadcopters
	for idS, quadQ in pairs(vns.childrenRolesVnsTT.quads) do
		-- calc the rallypoint in his perspective
		local thN = quadQ.dirN
		local thRadN = thN * math.pi / 180
		local newRallyV = {
			x =  (0 - quadQ.locV.x) * math.cos(thRadN)
			    +(0 - quadQ.locV.y) * math.sin(thRadN),
			y = -(0 - quadQ.locV.x) * math.sin(thRadN) 
			    +(0 - quadQ.locV.y) * math.cos(thRadN), 
		}
		-- calc fly dir in his perspective
		local dis = math.sqrt(quadQ.locV.x * quadQ.locV.x + quadQ.locV.y * quadQ.locV.y)
		local dirV = {}
		if dis > 360 then
			dirV.x =  (0 - quadQ.locV.x) * math.cos(thRadN)
			         +(0 - quadQ.locV.y) * math.sin(thRadN)
			dirV.y = -(0 - quadQ.locV.x) * math.sin(thRadN) 
			         +(0 - quadQ.locV.y) * math.cos(thRadN)
			dirV.x = dirV.x / dis * 10
			dirV.y = dirV.y / dis * 10
		else
			dirV.x = 0
			dirV.y = 0
		end

		-- calc rotate 
		local dirQuadtoCenter = calcDir(quadQ.locV, {x=0, y=0})
		local difN = dirQuadtoCenter - quadQ.dirN
		while difN > 180 do difN = difN - 360 end
		while difN < -180 do difN = difN + 360 end

		print("i am", getSelfIDS(), "i send a fly cmd")
		sendCMD(idS, "fly", {newRallyV.x, newRallyV.y, dirV.x, dirV.y, difN})
	end

-- recruit new robots ------------------------------
	for i, robotR in ipairs(robotsRT) do
		if vns.childrenVnsT[robotR.idS] == nil then
			-- a new robot
			sendCMD(robotR.idS, "recruit", {math.random()})
			local vVns = VNS:new{
				idS = robotR.idS, locV = robotR.locV, 
				dirN = robotR.dirN, typeS = "robot", 
				stateS = "2",
			}
			vns:add(vVns, "waitingAnswer")
		end
	end

print(getSelfIDS(), vns.stateS)
print("childrenlist:")
for i, vVns in pairs(vns.childrenVnsT) do
	print("\t",vVns.idS, vVns.roleS, vVns.parentS)
end

print("grouplist:")
for i, vVnsT in pairs(vns.childrenRolesVnsTT) do
	print("\t", i)
	for j, vVns in pairs(vVnsT) do
		print("\t\t", vVns.idS)
	end
end

-- buffer new robots ----------------------------------
--[[
	for idS, robotR in pairs(vns.childrenRolesVnsTT.new) do
		vns:changeRole(idS, "waitingAnswer")
	end
--]]
end

-------------------------------------------------------------------
function destroy()
	-- put your code here
end

------------------------------------------------------------------------
--   Customize Functions
------------------------------------------------------------------------

-- calc -----------------------------------------

function calcFlux(focalPosV, robotsRT, stateS)
	local length = 100
	local focalPosV3 = Vec3:create(focalPosV.x, focalPosV.y, 0)
	local points = {
		Vec3:create(-length, -length, 0),
		Vec3:create(-length,  length, 0),

		--Vec3:create( 0,      -length, 0),

		--Vec3:create(-length,  0,      0),
		--Vec3:create( length,  0,      0),

		--Vec3:create( 0,       length, 0),

		Vec3:create( length, -length, 0),
		Vec3:create( length,  length, 0),
	}

	if stateS == "reporting" then
		points[3] = nil
		points[4] = nil
	end

	local flux = Vec3:create(0, 0, 0)
	for i, pointV3 in ipairs(points) do
		local RV3 = focalPosV3 - pointV3
		flux = flux - RV3:nor() / (RV3:len())
	end

	for idS, robotR in pairs(robotsRT) do
		local otherRV3 = Vec3:create(robotR.locV.x, robotR.locV.y, 0)
		local RV3 = focalPosV3 - otherRV3
		flux = flux + 1.3 * RV3:nor() / (RV3:len() )
	end

	return flux
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
		i = i + 4
		--dataNST[i+4] = v.parent
		--i = i + 5
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
		i = i + 4
		--robotsRT[j].parent = dataNST[i+4]
		--i = i + 5
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

function calcQuadQ(fromIDS, robotsRT, receivedRobotsRT)
	local paraT = {} -- rotation and translation parameters
	local markidS
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

			markidS = vR.idS
			break -- one is enough
		end
	end

	if paraT.thN == nil then
		return nil
	else
		return {locV = {x = paraT.x,
		                y = paraT.y,},
				dirN = paraT.thN,
				idS = fromIDS,
				markidS = markidS,
		       }
	end
end

function calcCoor(_receivedRobotsRT, _receivedBoxesVT, _QuadQ)
	local thN = _QuadQ.dirN
	local thRadN = thN * math.pi / 180
	-- robots --
	for i, vR in ipairs(_receivedRobotsRT) do
		local x = vR.locV.x * math.cos(thRadN) - 
		          vR.locV.y * math.sin(thRadN) + _QuadQ.locV.x
		local y = vR.locV.x * math.sin(thRadN) + 
		          vR.locV.y * math.cos(thRadN) + _QuadQ.locV.y
		vR.locV.x = x
		vR.locV.y = y
		vR.dirN = (vR.dirN + thN) % 360  
		_receivedBoxesVT[vR.idS] = vR
	end

	-- boxes --
	for i, vV in ipairs(_receivedBoxesVT) do
		local x = vV.x * math.cos(thRadN) - 
		          vV.y * math.sin(thRadN) + _QuadQ.locV.x
		local y = vV.x * math.sin(thRadN) + 
		          vV.y * math.cos(thRadN) + _QuadQ.locV.y
		vV.x = x 
		vV.y = y 
	end
end

function joinRobots(_robotsRT, _receivedRobotsRT)
	local robotsRT = tableCopy(_robotsRT)
	for idS, vR in pairs(_receivedRobotsRT) do
		if robotsRT[idS] == nil then
			robotsRT[idS] = vR
		end
	end
	return robotsRT
end

function subtractRobots(_robotsRT, _subRobotsRT)
	local robotsRT = tableCopy(_robotsRT)
	for idS, vR in pairs(_subRobotsRT) do
		robotsRT[idS] = nil
	end
	return robotsRT
end

function joinBoxes(_boxesVT, _receivedBoxesVT)
	local boxesVT = _boxesVT
	local n = #boxesVT
	for i, receivedBoxV in ipairs(_receivedBoxesVT) do
		local flag = 0
		for j, boxV in ipairs(boxesVT) do
			local x = boxV.x - receivedBoxV.x
			local y = boxV.y - receivedBoxV.y
			local disN = math.sqrt(x * x + y * y)
			if disN < 15 then -- else continue
				flag = 1
				break
			end
		end
		if flag == 0 then
			n = n + 1
			boxesVT[nBoxes] = receivedBoxV 
		end
	end
	return boxesVT
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

		--robotsRT[i] = {locV = locV, dirN = dirN, idS = idS, parent = getSelfIDS()}
		robotsRT[i] = {locV = locV, dirN = dirN, idS = idS, }
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

--------------- drive Robots ------------------------
function setRobotVelocity(id, x,y)
	sendCMD(id, "setspeed", {x, y})
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
