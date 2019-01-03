-- Use Shift + Click to select a robot
-- When a robot is selected, its variables appear in this editor

-- Use Ctrl + Click (Cmd + Click on Mac) to move a selected robot to a different location

-- Put your global variables here

require("PackageInterface")
State = require("StateMachine")
--require("debugger")

----------------------------------------------------------------------------------
--   State Machine
----------------------------------------------------------------------------------

stateMachine = State:create{
	initial = "randomWalk",
	substates = 
	{
		randomWalk = State:create{
			transMethod = function()
				local fromID_s, cmd_s, rxNumbers_nt = getCMD()
				if cmd_s == "recruit" then
					return "beingDriven"
				end
			end,
			initial = "straight",
			substates = {
				straight = State:create{
					enterMethod = function() setSpeed(1, 1) end,
				}, 
			},
		}, -- end of randomWalk
		beingDriven = State:create{
			enterMethod = function() setSpeed(0, 0) print("i am beingDriven") end,
			transMethod = function()
				local fromID_s, cmd_s, rxNumbers_nt = getCMD()
				if cmd_s == "setspeed" then
					setSpeed(rxNumbers_nt[1], rxNumbers_nt[2])
				end
				if cmd_s == "dismiss" then
					return "randomWalk"
				end
				if fromID_s ~= nil then
					local txBytes_bt = tableToBytes(fromID_s, 
					                                robot.id, 
					                                "sensor",
					                                robot.proximity)
					robot.radios["radio_0"].tx_data(txBytes_bt)
				end
			end,
		}, -- end of beingDriven
	} -- end of substates of stateMachine
} -- end of stateMachine

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
	stateMachine:step()
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

function getCMD()
	for index, rxBytes_bt in pairs(robot.radios["radio_0"].rx_data) do	-- byte table
		local toID_s, fromID_s, cmd_s, rxNumbers_nt = bytesToTable(rxBytes_bt)
		if toID_s == robot.id then
			return fromID_s, cmd_s, rxNumbers_nt
		end
	end
end
