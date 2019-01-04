-- Put your global variables here

require("PackageInterface")
--require("debugger")

----------------------------------------------------------------------------------
--   ARGoS Functions
----------------------------------------------------------------------------------
--[[ This function is executed every time you press the 'execute' button ]]
-------------------------------------------------------------------
function init()
	reset()
end

-------------------------------------------------------------------
--[[ This function is executed at each time step
     It must contain the logic of your controller ]]
-------------------------------------------------------------------
function step()
	-- detect boxes into boxPos[i]
	local leds = robot.cameras.fixed_camera.led_detector
	local boxN = #leds
	local boxPos = {}
	if #leds > 0 then
		for i, detection in ipairs(leds) do
			boxPos[i] = getBoxPosition(detection)
		end	
	else
		return -1
	end

	--[[
	-- get robot poximitiy sensors
	local sensors = {}
	for index, rxNumber in pairs(robot.radios["radio_0"].rx_data) do
		local rxBytes = robot.radios["radio_0"].rx_data[1]
		local toID, fromID, cmd, rxNumber = bytesToTable(rxBytes)
		sensors[fromID] = rxNumber
	end
	--]]

	-- for each robot
	local tags = robot.cameras.fixed_camera.tag_detector
	local robotN = #tags
	for index,tag in pairs(tags) do
		-- get robot id
		local robotID = tag.payload

		-- get robot position
		local robotPos, robotDir = getRobotPosition(tag)
			-- pos (0,0) in the middle, x+ right, y+ up , 
			-- dir from -180 to 180, x+ as 0
		local headPos = getRobotHead(tag)

		-- calculate something
		local boxDir = getBoxDirtoRobot(robotPos, boxPos[1])
		local dif = boxDir - robotDir
		while dif > 180 do
			dif = dif - 360
		end

		while dif < -180 do
			dif = dif + 360
		end

		if dif > 10 or dif < -10 then
			if (dif > 0) then
				setRobotVelocity(robotID, -1, 1)
			else
				setRobotVelocity(robotID, 1, -1)
			end
		else
			setRobotVelocity(robotID, 1, 1)
		end

						--[[ substitude for angle alignment
						a=(robotPos.y-boxPos.y)/(robotPos.x-boxPos.x)
						b= robotPos.y - a*(robotPos.x)
						logerr("dif in step," .. string.format("%.0f", dif))
						if ((a*headPos.x + b - headPos.y)>5 or (a*headPos.x + b - headPos.y)<-5) then
							if ((headPos.x-robotPos.x)*(boxPos.y-robotPos.y)-(headPos.y-robotPos.y)*(boxPos.x-robotPos.x))<0 then
										setRobotVelocity(-1, 1)
										else
										setRobotVelocity(1, -1)
										end
						else
							setRobotVelocity(1, 1)
						end	
						--]]
	end
end

-------------------------------------------------------------------
--[[ This function is executed every time you press the 'reset'
     button in the GUI. It is supposed to restore the state
     of the controller to whatever it was right after init() was
     called. The state of sensors and actuators is reset
     automatically by ARGoS. ]]
-------------------------------------------------------------------
function reset()
end

-------------------------------------------------------------------
--[[ This function is executed only once, when the robot is removed
     from the simulation ]]
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
function setVelocity(x,y,theta)
	robot.joints.axis0_axis1.set_target(x)
	robot.joints.axis1_axis2.set_target(y)
	robot.joints.axis2_body.set_target(theta)
end

-------------------------------------------------------------------
-- get robot
-------------------------------------------------------------------
function getRobotPosition(tag)
	local deg = calcRobotDir(tag.corners)
		-- a direction is a number from 0 to 360, 
		-- with 0 as the x+ axis of the quadcopter
	local pos = {}
	pos.x = tag.center.x - 320
	pos.y = tag.center.y - 240
	pos.y = -pos.y 				-- make it left handed coordination system
	return pos, deg
end

-------------------------------------------------------------------
function calcRobotDir(corners)
	-- a direction is a number from -180 to 180, 
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
	pos.x = ((tag.corners[3].x + tag.corners[4].x) / 2)- 320
	pos.y = ((tag.corners[3].y + tag.corners[4].y) / 2) - 240
	pos.y = -pos.y 				-- make it left handed coordination system
	return pos
end


-------------------------------------------------------------------
-- get box
-------------------------------------------------------------------
function getBoxPosition (detection)
	local pos = {}
	pos.x = detection.center.x - 320
	pos.y = detection.center.y - 240
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
