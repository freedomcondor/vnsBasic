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
			enterMethod = function() print(getPrintTabs(), "random") end,
			transMethod = function(fdata, data, para)
				local cmdListCT = getCMDListCT()		
					--CT:  cmd array, cmd:{fromIDS,cmdS, dataNST}
				-- find the max number of recruits
				local maxRecruit = -1
				local hasRecruit = false
				for i, cmdC in ipairs(cmdListCT) do
					if cmdC.cmdS == "recruit" then
						hasRecruit = true
						if cmdC.dataNST[1] > maxRecruit then
							fdata.parentID = cmdC.fromIDS
							maxRecruit = cmdC.dataNST[1] 
						end
					end
				end
				-- deny all other recruits 
				for i, cmdC in ipairs(cmdListCT) do -- TODO: two recruits
					if cmdC.cmdS == "recruit" and 
					   cmdC.fromIDS ~= fdata.parentID then
						sendCMD(cmdC.fromIDS, "deny", {fdata.parentID})
					end
				end
				if hasRecruit == true then
					return "beingDriven"
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
			enterMethod = function() setSpeed(0, 0) print(getPrintTabs(), "driven") end,
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
						print(getPrintTabs(), "disfdr")
						return "randomWalk"
					elseif cmdC.cmdS == "turnBySelf" and cmdC.fromIDS == fdata.parentID then
						fdata.turnDir = cmdC.dataNST[1]
						return "turnBySelf"
					elseif cmdC.cmdS == "recruit" then
						sendCMD(cmdC.fromIDS, "deny", {fdata.parentID})
						--standStill()
						--return "END"
					end
				end
				if noCMD == true then
					-- I didn't get a valid command when I should be
					data.lostCountN = data.lostCountN + 1
					if data.lostCountN > 0 then
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
			data = {lostCountN = 0,},
			enterMethod = function(fdata, data, para)
				print(getPrintTabs(), "t " .. fdata.turnDir)
				if     fdata.turnDir == "left"  then turnLeft()
		        elseif fdata.turnDir == "right" then turnRight() end
			end,
			transMethod = function(fdata, data, para)
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
						print(getPrintTabs(), "disftur")
						return "randomWalk"
					elseif cmdC.cmdS == "recruit" then
						sendCMD(cmdC.fromIDS, "deny", {fdata.parentID})
					end
				end
				if noCMD == true then
					-- I didn't get a valid command when I should be
					data.lostCountN = data.lostCountN + 1
					if data.lostCountN > 0 then
						-- lost
						print(getPrintTabs(), "lost")
						return "randomWalk"
					end
				else
					data.lostCountN = 0
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

function getPrintTabs()
	local num = nil
	if getSelfIDS() == "vehicle0" then num = 0
	elseif getSelfIDS() == "vehicle1" then num = 1
	elseif getSelfIDS() == "vehicle2" then num = 2
	elseif getSelfIDS() == "vehicle3" then num = 3
	elseif getSelfIDS() == "vehicle4" then num = 4
	elseif getSelfIDS() == "vehicle5" then num = 5
	elseif getSelfIDS() == "vehicle6" then num = 6
	elseif getSelfIDS() == "vehicle7" then num = 7
	elseif getSelfIDS() == "vehicle8" then num = 8
	elseif getSelfIDS() == "vehicle9" then num = 9
	elseif getSelfIDS() == "vehicle10" then num = 10
	elseif getSelfIDS() == "vehicle11" then num = 11
	elseif getSelfIDS() == "vehicle12" then num = 12
	elseif getSelfIDS() == "vehicle13" then num = 13
	elseif getSelfIDS() == "vehicle14" then num = 14
	elseif getSelfIDS() == "vehicle15" then num = 15
	end

	str = ""
	for i = 1, num do
		str = str .. "\t\t"
	end
	return str
end

-- motion control --
local baseSpeedN = 20
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
