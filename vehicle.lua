-- Use Shift + Click to select a robot
-- When a robot is selected, its variables appear in this editor

-- Use Ctrl + Click (Cmd + Click on Mac) to move a selected robot to a different location



-- Put your global variables here

package.path = package.path .. ";./src/testing/examples/?.lua"
require("PackageInterface")

--require("debugger")

----------------------------------------------------------------------------------
--   ARGoS Functions
----------------------------------------------------------------------------------
--[[ This function is executed every time you press the 'execute' button ]]
-------------------------------------------------------------------
function init()
	robot.tags.set_all_payloads(robot.id)
	reset()
end



-------------------------------------------------------------------
--[[ This function is executed at each time step
     It must contain the logic of your controller ]]
-------------------------------------------------------------------
function step()
	-- get command and set speed accordingly
	if #robot.radios["radio_0"].rx_data ~= 0 then
		local rxBytes = robot.radios["radio_0"].rx_data[1]
		local rxNumbers = bytesToTable(rxBytes)
		setSpeed(rxNumbers[1], rxNumbers[2])
	end

	-- report proximity sensor readings
	local txBytes = tableToBytes(robot.proximity)
	robot.radios["radio_0"].tx_data(txBytes)
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
function setSpeed(x,y)
	robot.joints.base_wheel_left.set_target(x)
	robot.joints.base_wheel_right.set_target(-y)
end
