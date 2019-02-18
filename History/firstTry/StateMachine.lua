------------------------------------------------------
-- a lua State Machine
-- Weixu Zhu (Harry)
-- version 2.1
-- 		-- added: method can access: father data,  self data, step para
-- version 2.2
-- 		-- added: CLASSSTATEMACHINE = true
-- version 2.3
-- 		-- added: enterMethod return 1 for jumping a step for transMethod check
-- 		-- changed: in step(), if no substates, return -1 instead of 1
------------------------------------------------------
function tableCopy(x)
	local image = {}
	setmetatable(image,getmetatable(x))
	if type(x) ~= "table" then return x end
	for index,value in pairs(x) do
		image[index] = tableCopy(value)
	end
	return image
end
------------------------------------------------------
local StateMachine = {CLASSSTATEMACHINE = true}
StateMachine.__index = StateMachine

StateMachine.INIT = {class = "CLASSFLAG",id = "INIT"}	-- flag constant
StateMachine.EXIT = {class = "CLASSFLAG",id = "EXIT"}

function StateMachine:new(option)
	return self:create(option)
end

function StateMachine:create(option)
	local instance = {}
	setmetatable(instance,self)

	-- validation check
	if option == nil then return nil end
	if option.substates ~= nil and option.initial == nil then
		print("bad create option: there are substates, but no initial assigned\n")
		return nil
	end

	-- copy configuration
	instance.id = option.id
	instance.substates = tableCopy(option.substates)
	if instance.substates ~= nil then
		instance.substates.INIT = StateMachine.INIT
		instance.substates.EXIT = StateMachine.EXIT
	end
	instance.data = tableCopy(option.data) -- or nil?
	instance.onExit = tableCopy(option.onExit) -- or nil?

	if type(option.enterMethod) == "function" then
		instance.enterMethod = tableCopy(option.enterMethod)	-- else nil
	end
	if type(option.transMethod) == "function" then
		instance.transMethod = tableCopy(option.transMethod)
	elseif type(option.method) == "function" then		-- legacy
		instance.transMethod = tableCopy(option.method)
	end
	if type(option.leaveMethod) == "function" then
		instance.leaveMethod = tableCopy(option.leaveMethod)
	end
	if type(option.initMethod) == "function" then
		instance.initMethod = tableCopy(option.initMethod)
	end

	instance.currentState = StateMachine.INIT
	instance.initState = option.initial
	instance.nextState = option.initial
	
	return instance
end

function StateMachine:init()
	self.currentState = StateMachine.INIT
	self.nextState = self.initState
	if self.initMethod ~= nil then
		self.initMethod(self.data)
	end
end

function StateMachine:run()
	local ret = self:step()
	while ret == 1 do
		ret = self:step()
	end
end

function StateMachine:stepSingle(para)		-- legacy mode
	self:step(para)
end

function StateMachine:step(para)	
-- return 1 means ongoing, return -1 means finish
	-- if I don't have substate, joking, return -1
	if self.substates == nil then
		return -1
	end

	-- check nextState
	-- self.nextState is the cue, if nil means the State stays, skip enterMethod
	if self.nextState ~= nil then
		if self.nextState == "EXIT" then
			self.nextState = nil
			self.currentState = StateMachine.EXIT
			return -1
		end
		if self.substates[self.nextState] ~= nil then
			self.currentState = self.substates[self.nextState]
			self.currentState:init()
			if self.currentState.enterMethod ~= nil then
				local retEnter = nil
				retEnter = self.currentState.enterMethod(self.data, self.currentState.data, para)
				-- if enterMethod return 1, means jump to next step for transMethod
				if retEnter == 1 then	
					self.nextState = nil
					return 1
				end
			end
		end
	end

	-- check transMethod
	self.nextState = nil
	local retNext = nil
	if self.currentState.transMethod ~= nil then
		retNext = self.currentState.transMethod(self.data, self.currentState.data, para)
	end
	if retNext ~= nil then
		if self.currentState.leaveMethod ~= nil then
			self.currentState.leaveMethod(self.data, self.currentState.data, para)
		end
		self.nextState = retNext
		if retNext == "EXIT" then
			self.nextState = nil
			self.currentState = StateMachine.EXIT
			return -1
		else
			return 1
		end
	end

	-- run step
	local ret = nil
	if self.currentState.step ~= nil then
		ret = self.currentState:step(para)
	end
	if ret == -1 then
		if self.currentState.onExit ~= nil then
			self.nextState = self.currentState.onExit
			if self.currentState.leaveMethod ~= nil then
				self.currentState.leaveMethod(self.data, self.currentState.data, para)
			end
			if self.nextState == "EXIT" then 
				return -1 
			end
		end
	end

	return 1
end

return StateMachine
