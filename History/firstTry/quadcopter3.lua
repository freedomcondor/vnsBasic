----------------------------------------------------------------------------------
--   Global Variables
----------------------------------------------------------------------------------

require("PackageInterface")
--require("debugger")

local STATE = "recruiting"
local SON_VEHICLE_NAME = nil
local check = 0
local targetBoxV = nil
local circulate = 0
local push = 0
local averagePoint
local timeStepN = 0
local dis2ToAve = 0
local dis2BoxToAve = 0
local dis1ToAve = 0
local adjust = 0
----------------------------------------------------------------------------------
--   ARGoS Functions
----------------------------------------------------------------------------------
function init()
	reset()
end

-------------------------------------------------------------------
function step()
	timeStepN = timeStepN + 1
	-- detect boxes into boxesVT[i]
	--local boxPos_vt = getBoxesVT()	
	local boxesVT = getBoxesVT()	
		-- V means vector = {x,y}

	-- detect robots into robotsRT[i] and robotsRT[id]
	local robotsRT = getRobotsRT()
		-- R for robot = {locV, dirN, idS}

	if STATE == "recruiting" then
		-- for each robot, if it has a box to move
		--for i, vehicleR in ipairs(robotsRT) do
			--local targetBoxV = getTargetBoxV(vehicleR.locV, boxesVT)]
			averagePoint = getAveragePoint(boxesVT)
			--if check == 0 then
			local targetBoxV = getTargetBoxV(boxesVT, averagePoint)
				--check = 1
			--end
			local targetRobotV = getTargetRobotV(targetBoxV, robotsRT)
			if targetBoxV ~= nil and targetRobotV ~= nil then
				--sendCMD(vehicleR.idS, "recruit")
				sendCMD(targetRobotV.idS, "recruit")
				STATE = "driving"
				--SON_VEHICLE_NAME = vehicleR.idS
				SON_VEHICLE_NAME = targetRobotV.idS
				print(getSelfIDS(), ": i recruit vehicle", SON_VEHICLE_NAME)
				return -- return of step()
			end
		--end
	else if STATE == "driving" then
		--print(averagePoint.x)
		local sonVehicle = robotsRT[SON_VEHICLE_NAME]
		if sonVehicle ~= nil then
			--local targetBoxV = getTargetBoxV(sonVehicle.locV, boxesVT)
			local targetBoxV = getTargetBoxV(boxesVT, averagePoint)
			
			if targetBoxV ~= nil then
			local baseSpeedN = 7
			--setRobotVelocity(SON_VEHICLE_NAME, baseSpeedN, baseSpeedN)
					--[[print(sonVehicle.idS)]]
					local boxDirtoRobotN = getBoxDirtoRobot(sonVehicle.locV, targetBoxV)
					local difBoxN = boxDirtoRobotN - sonVehicle.dirN
					while difBoxN > 180 do
						difBoxN = difBoxN - 360
					end
		
					while difBoxN < -180 do
						difBoxN = difBoxN + 360
					end
					-----------------------------------
					local AverageDirtoRobotN = getAveDirtoRobot(sonVehicle.locV, averagePoint)
					local difAveN = AverageDirtoRobotN - sonVehicle.dirN
					while difAveN > 180 do
						difAveN = difAveN - 360
					end
		
					while difAveN < -180 do
						difAveN = difAveN + 360
					end
					-----------------------------------
					local baseSpeedN = 7
					-- Distance Computing: between the selected robot and the selected box
					local relV = {x = sonVehicle.locV.x - targetBoxV.x,
								   y = sonVehicle.locV.y - targetBoxV.y,}
					local disToBox = math.sqrt(relV.x * relV.x +
									relV.y * relV.y )
									
					-- Distance Computing: between the selected robot and the average point
					local relAveV = {x = sonVehicle.locV.x - averagePoint.x,
								   y = sonVehicle.locV.y - averagePoint.y,}
					local disToAve = math.sqrt(relAveV.x * relAveV.x +
									relAveV.y * relAveV.y )
					-- Distance Computing: between the selected box and the average point
					local relBoxToAveV = {x = targetBoxV.x - averagePoint.x,
								   y = targetBoxV.y - averagePoint.y,}
					local disBoxToAve = math.sqrt(relBoxToAveV.x * relBoxToAveV.x +
									relBoxToAveV.y * relBoxToAveV.y )
					if circulate == 0 then
						if disToBox > 100 then
							if difBoxN > 10 or difBoxN < -10 then
								if (difBoxN > 0) then
									setRobotVelocity(SON_VEHICLE_NAME, -baseSpeedN, baseSpeedN)
								else
									setRobotVelocity(SON_VEHICLE_NAME, baseSpeedN, -baseSpeedN)
								end
							else
								setRobotVelocity(SON_VEHICLE_NAME, baseSpeedN, baseSpeedN)
								print(circulate)
							end
						else
							print('enough')
							circulate = 1
						end	
					elseif circulate == 1 then
						-- we are goind to find a line formula passing from the average point and the target bax: y=mx+b
						local m = (targetBoxV.y - averagePoint.y) / (targetBoxV.x - averagePoint.x)
						local b = targetBoxV.y - (m * targetBoxV.x)
						local whilecheck = 0
						
							if ((sonVehicle.locV.y - m * sonVehicle.locV.x - b)> 5 or (sonVehicle.locV.y - m * sonVehicle.locV.x - b)< -5) then
								print('moveAround1')
								moveAround(sonVehicle, targetBoxV, difBoxN)  
							else
								-- Distance Computing: between the selected robot and the average point
								local relAve2V = {x = sonVehicle.locV.x - averagePoint.x,
											   y = sonVehicle.locV.y - averagePoint.y,}
								local disToAve2 = math.sqrt(relAve2V.x * relAve2V.x +
												relAve2V.y * relAve2V.y )
								-- Distance Computing: between the selected box and the average point
								local relBoxToAve2V = {x = targetBoxV.x - averagePoint.x,
											   y = targetBoxV.y - averagePoint.y,}
								local disBoxToAve2 = math.sqrt(relBoxToAve2V.x * relBoxToAve2V.x +
												relBoxToAve2V.y * relBoxToAve2V.y )
								if disBoxToAve2 > disToAve2 then
									print('moveAroun2')
									moveAround(sonVehicle, targetBoxV, difBoxN)
								else
									--print('pushhh')
									circulate = 2;
									adjust = 1
									print('changing to adjust')
								end
							end
							--print(circulate)
					elseif adjust == 1 then	
						if difBoxN > 2 or difBoxN < -2 then
							if (difBoxN > 0) then
								pushForward(SON_VEHICLE_NAME, -1, 2)
							else
								pushForward(SON_VEHICLE_NAME, 2, -1)
							end
						else
							pushForward(SON_VEHICLE_NAME, 5, 5)
							push = 1
							adjust = 0
							print('ADJUST PHASE')
						end
					elseif push == 1 then
							-- Distance Computing: between the selected box and the average point
							targetBoxV = getTargetBoxV(boxesVT, averagePoint)
							relBoxToAveV = {x = targetBoxV.x - averagePoint.x,
										   y = targetBoxV.y - averagePoint.y,}
							disBoxToAve = math.sqrt(relBoxToAveV.x * relBoxToAveV.x +
											relBoxToAveV.y * relBoxToAveV.y )
							if timeStepN % 2 == 1 then
								print('TIMESTEPPPPPP')
								-- Distance Computing: between the selected robot and the average point
								dis2BoxToAve = math.sqrt(relBoxToAveV.x * relBoxToAveV.x +
									relBoxToAveV.y * relBoxToAveV.y )
								--dis2ToAve = math.sqrt(relV.x * relV.x +
									--relV.y * relV.y )
								--if (dis2ToAve - dis1ToAve > 0) then\
								if (dis2BoxToAve - dis1BoxToAve > 0) then
									print('STOPPPPP PUSHINGGGGG')
									push = 0
									circulate = 0
									STATE = "recruiting"
								end
							elseif timeStepN % 2 == 0 then
							print('Step22')
								-- Distance Computing: between the selected robot and the average point
								dis1BoxToAve = math.sqrt(relBoxToAveV.x * relBoxToAveV.x +
									relBoxToAveV.y * relBoxToAveV.y )
								--dis1ToAve = math.sqrt(relV.x * relV.x +
									--relV.y * relV.y )
							end
							if disBoxToAve > 80 then
								print(disToAve)
								print(disBoxToAve)
								if difBoxN > 2 or difBoxN < -2 then
									if (difBoxN > 0) then
										pushForward(SON_VEHICLE_NAME, -1, 5)
									else
										pushForward(SON_VEHICLE_NAME, 5, -1)
									end
								else
									pushForward(SON_VEHICLE_NAME, 5, 5)
									print('pushhh')
								end
							else
								--setRobotVelocity(SON_VEHICLE_NAME, baseSpeedN, baseSpeedN)
								print('end pushhhh')
								push = 0
								circulate = 0
								STATE = "recruiting"
							end
					end
			else
				-- no box to move, dismiss robot
				print(getSelfIDS(), ": i dismiss vehicle", SON_VEHICLE_NAME)
				sendCMD(sonVehicle.idS, "dismiss")
				check = 0
				circulate = 0
				STATE = "recruiting"
				SON_VEHICLE_NAME = nil
				return
			end
		else
			print(getSelfIDS(), ": i lost vehicle", SON_VEHICLE_NAME)
			STATE = "recruiting"
			circulate = 0
			SON_VEHICLE_NAME = nil
			return
			-- if I lost the robot (maybe the robot is out of range)
		end
	end end -- two ends of STATE == "recruting" and "driving"
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
function setRobotAround(id, x,y)
	local bytes = tableToBytes(id, robot.id , "setaround", {x,y})
	robot.radios["radio_0"].tx_data(bytes)
end

-------------------------------------------------------------------
function pushForward(id, x,y)
	local bytes = tableToBytes(id, robot.id , "push", {x,y})
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
		local headV = getRobotHead(tagDetectionT)
			-- locV V for vector {x,y}
			-- loc (0,0) in the middle, x+ right, y+ up , 
			-- dir from 0 to 360, x+ as 0

		robotsRT[i] = {locV = locV, headV = headV, dirN = dirN, idS = idS}
		robotsRT[idS] = robotsRT[i]
	end
	--print('info')
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
--function getTargetBoxV(robotLocV, boxesVT)
function getTargetBoxV(boxesVT, ave)
-- this function finds a box from boxes array for a robot to push based on:
-- if the box is outside the center zone (5000 length)
-- if the angle between the robot to the center (0,0)
--              and     the robot to the box
--        is small enough (cos >0.9)
-- if the box is towards inside not outside
-- then return the box location
-- if no such box, return nil
	--local disR = robotLocV.x * robotLocV.x +
	           --  robotLocV.y * robotLocV.y
	local average = {}
	-----------------------------------------------#		   
	--[[local average = {}
	local sumX=0 
	local sumY=0
	
	--for i, boxV in ipairs(boxesVT) do
		--counter = counter + 1
	local length = #boxesVT
	for i=1,length do
		sumX = sumX + boxesVT[i].x
		sumY = sumY + boxesVT[i].y
	end]]
	-----------------------------------------------#
		--local disBoxtoCenterN = boxV.x * boxV.x + boxV.y * boxV.y
		--[[if disBoxtoCenterN > 5000 then
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
		end]]
	--end
	local closestBoxtoAverage = nil
	-------------------------------------------------#
	--average = {x=sumX/length, y=sumY/length}
	average = {x=ave.x, y=ave.y}
	local length = #boxesVT
	-------------------------------------------------#
	local minDis = 1000000
	for i=1, length do
		local relativeV = {x = boxesVT[i].x - average.x,
			                   y = boxesVT[i].y - average.y,}
		local disToAverage = math.sqrt(relativeV.x * relativeV.x +
			                    relativeV.y * relativeV.y )
		if (disToAverage < minDis and disToAverage>80) then
			minDis = disToAverage
			closestBoxtoAverage = boxesVT[i]
		end
	end
	return closestBoxtoAverage
	--return nil
end

-------------------------------------------------------------------
function getAveragePoint(boxesVT)
	local average = {}
	local sumX=0 
	local sumY=0
	
	--for i, boxV in ipairs(boxesVT) do
		--counter = counter + 1
	local length = #boxesVT
	for i=1,length do
		sumX = sumX + boxesVT[i].x
		sumY = sumY + boxesVT[i].y
	end
	average = {x=sumX/length, y=sumY/length}
	return average
end

-------------------------------------------------------------------
function getTargetRobotV(closestBoxtoAverage, robotsRT)
	local minDis = 1000000
	local length = #robotsRT
	local closestRobottoAverage = nil
	for i=1, length do
		local relativeV = {x = robotsRT[i].locV.x - closestBoxtoAverage.x,
			                   y = robotsRT[i].locV.y - closestBoxtoAverage.y,}
		local disToAverage = math.sqrt(relativeV.x * relativeV.x +
			                    relativeV.y * relativeV.y )
		if disToAverage < minDis then
			minDis = disToAverage
			closestRobottoAverage = robotsRT[i]
		end
	end
	return closestRobottoAverage
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
function getAveDirtoRobot(robotPos, ave)
	local deg = calcDir(robotPos, ave)
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

---------------------------------------------------------------------
function moveAround(vehicle, targetV, difBoxN)
	print('fggf')
	dis1 = (vehicle.locV.x-targetV.x)*(vehicle.locV.x-targetV.x)+ (vehicle.locV.y-targetV.y)*(vehicle.locV.y-targetV.y)
	dis2 = (vehicle.headV.x-targetV.x)*(vehicle.headV.x-targetV.x) + (vehicle.headV.y-targetV.y)*(vehicle.headV.y-targetV.y)
	print('function')
	local baseSpeedN = 5
	if dis1>100 then
		if difBoxN > 10 or difBoxN < -10 then
			if (difBoxN > 0) then
				setRobotVelocity(vehicle.idS, -baseSpeedN, baseSpeedN)
			else
				setRobotVelocity(vehicle.idS, baseSpeedN, -baseSpeedN)
			end
		else
				setRobotVelocity(vehicle.idS, baseSpeedN, baseSpeedN)
				print('INSIDE MOVEAROUN GET CLOSER TO THE OBJECT')
		end
	else
		if dis2>dis1 then

			setRobotAround(vehicle.idS, 2, 5.5)
			
			print('CounterClockwise')
							
		elseif dis2<dis1 then
			
			setRobotAround(vehicle.idS, 5.5, 2)
			
			print('Clockwise')
			
		elseif dis2==dis1 then
		
			setRobotAround(vehicle.idS, 5, 5)
			
			print('streight')
			
		end 
	end
	--setRobotVelocity(SON_VEHICLE_NAME, baseSpeedN, baseSpeedN)
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
