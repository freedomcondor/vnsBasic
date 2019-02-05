------------------------------------------------------------------------
--   Global Variables
------------------------------------------------------------------------

require("PackageInterface")
local State = require("StateMachine")
--require("debugger")

------------------------------------------------------------------------
--   State Machine
------------------------------------------------------------------------
stateMachine = State:create{
	data = {parentID = nil, turnDir = nil,},
	initial = "randomWalk",
	substates = {
	-- randomwalk --------------------
		randomWalk = State:create{
			transMethod = function(fdata, data, para)
				local cmdListCT = getCMDListCT()		
					--CT:  cmd array, cmd:{fromIDS,cmdS, dataNST}
				for i, cmdC in ipairs(cmdListCT) do
					if cmdC.cmdS == "recruit" then
						fdata.parentID = cmdC.fromIDS
						return "beingDriven"
					end
				end
			end,
			initial = "straight",
			substates = {
				straight = State:create{
					transMethod = function()
						if objFront() == true then return "turn" end
						sideForward((math.random() - 0.5) * 3)
					end,
				},
				turn = State:create{
					enterMethod = function()
						if math.random() > 0.5 then turnLeft()
						                       else turnRight() end
					end,
					transMethod = function()
						if objFront() == false then
							return "straight"
						end
					end,
				},
			},
		},
	-- end of randomwalk -------------
	-- beingDriven -------------------
		beingDriven = State:create{
			data = {lostCountN = 0,},
			enterMethod = function() setSpeed(0, 0) print(getSelfIDS(), ": I am recruited") end,
			transMethod = function(fdata, data, para)
				local cmdListCT = getCMDListCT()		
					--CT:  cmd array, cmd:{fromIDS,cmdS, dataNST}
				local noCMD = true
				for i, cmdC in ipairs(cmdListCT) do
					if cmdC.cmdS == "setspeed" and cmdC.fromIDS == fdata.parentID then
						setSpeed(cmdC.dataNST[1], cmdC.dataNST[2])
						sendCMD(cmdC.fromIDS, "sensor", getProximityTableNT())
						noCMD = false
					elseif cmdC.cmdS == "dismiss" and cmdC.fromIDS == fdata.parentID then
						fdata.parentID = nil
						return "randomwalk"
					elseif cmdC.cmdS == "turnBySelf" and cmdC.fromIDS == fdata.parentID then
						fdata.turnDir = cmdC.dataNST[1]
						return "turnBySelf"
					end
				end
				if noCMD == true then
					-- I didn't get a valid command when I should be
					data.countN = data.countN + 1
					if data.countN > 3 then
						-- lost
						return "randomWalk"
					end
				else
					data.countN = 0
				end
			end,
		},
	-- end of beingDriven ------------
	-- turnBySelf --------------------
		turnBySelf = State:create{
			enterMethod = function(fdata, data, para)
				if     fdata.turnDir == "left"  then turnLeft()
		        elseif fdata.turnDir == "right" then turnRight() end
			end,
			transMethod = function()
				if objFront() == false then goFront() end
				local cmdListCT = getCMDListCT()		
				local noCMD = true
				for i, cmdC in ipairs(cmdListCT) do
					if cmdC.cmdS == "keepgoing" and cmdC.fromIDS == fdata.parentID then
						noCMD = false
					elseif cmdC.cmdS == "beingDriven" and cmdC.fromIDS == fdata.parentID then
						return "beingDriven"
					elseif cmdC.cmdS == "dismiss" and cmdC.fromIDS == fdata.parentID then
						fdata.parentID = nil
						return "randomwalk"
					end
				end
				if noCMD == true then
					-- I didn't get a valid command when I should be
					data.countN = data.countN + 1
					if data.countN > 3 then
						-- lost
						return "randomWalk"
					end
				else
					data.countN = 0
				end
			end,
		},
	-- end of turnBySelf -------------
	}, -- end of substates
}

------------------------------------------------------------------------
--   ARGoS Functions
------------------------------------------------------------------------
function init()
	setTag(getSelfIDS())
	reset()
end

-------------------------------------------------------------------
function step()
	stateMachine:step()
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

-- motion control --
local baseSpeedN = 10
function standStill()
	setSpeed(0, 0)
end
function goFront()
	setSpeed(baseSpeedN, baseSpeedN)
end
function turnLeft()
	setSpeed(-baseSpeedN, baseSpeedN)
end
function turnRight()
	setSpeed(baseSpeedN, -baseSpeedN)
end
function sideForward(x) 
	-- 0 means no turn, just go Front, 1 means (0, 2*base), -1 means (2*base, 0)
	setSpeed(baseSpeedN - baseSpeedN * x, baseSpeedN + baseSpeedN * x)
end

-- sensor meaning --
function objFront()
	if getProximityN(1) ~= 0 or
	   getProximityN(2) ~= 0 or
	   getProximityN(12) ~= 0 then
		return true
	else
		return false
	end
end

------------------------------------------------------------------------
--   Lua Interface
------------------------------------------------------------------------
function setSpeed(x,y)
	robot.joints.base_wheel_left.set_target(x)
	robot.joints.base_wheel_right.set_target(-y)
end

function getProximityN(x)
	return robot.proximity[x]
end

function getProximityTableNT()
	return robot.proximity
end

function transData(xBT)
	robot.radios["radio_0"].tx_data(xBT)
end

function getReceivedDataTableBT()	--BT means byte table
	return robot.radios["radio_0"].rx_data
end

function getSelfIDS()
	return robot.id
end

function setTag(str)
	robot.tags.set_all_payloads(str)
end
