-- Put your global variables here

package.path = package.path .. ";./src/testing/examples/?.lua"
require("PackageInterface")

require("debugger")


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
	local tags = robot.cameras.fixed_camera.tag_detector
	local pos, dir
	if #tags ~= 0 then
		-- get robot position
		pos, dir = getRobotPosition(tags[1])	
			-- pos (0,0) in the middle, x+ right, y+ up , 
			-- dir from -180 to 180, x+ as 0

		-- get robot poximitiy sensors
		if #robot.radios["radio_0"].rx_data ~= 0 then
			local rxBytes = robot.radios["radio_0"].rx_data[1]
			local rxNumber = bytesToTable(rxBytes)
			for index, value in pairs(rxNumber) do
				print(index, value)
			end
		end

		-- control robot
		local speed = 1
		if dir < 5 and dir > -5 then
			speed = 0.1
		end
		if dir < 2 and dir > -2 then
			speed = 0
		end

		if dir > 0 then
			setRobotVelocity(speed, -speed)
		else
			setRobotVelocity(-speed, speed)
		end
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
	--set_velocity(0.1,0.1,0.5)
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
function setRobotVelocity(x,y)
	local bytes = tableToBytes{x,y}
	robot.radios["radio_0"].tx_data(bytes)
end

-------------------------------------------------------------------
function set_velocity(x,y,theta)
	robot.joints.axis0_axis1.set_target(x)
	robot.joints.axis1_axis2.set_target(y)
	robot.joints.axis2_body.set_target(theta)
end

-------------------------------------------------------------------
function getRobotPosition(tag)
	local deg = calcRobotDir(tag.corners)
		-- a direction is a number from -180 to 180, 
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
	local frontx = (corners[1].x + corners[2].x) / 2
	local fronty = (corners[1].y + corners[2].y) / 2
	local backx = (corners[3].x + corners[4].x) / 2
	local backy = (corners[3].y + corners[4].y) / 2
	local dirx = frontx - backx
	local diry = -(fronty - backy)	-- make it left handed
	local deg = math.atan(diry / dirx) * 180 / 3.1415926
	if dirx < 0 then
		deg = deg + 180
	end
	deg = deg - 90
	return deg
end
