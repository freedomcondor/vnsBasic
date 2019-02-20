------------------------------------------------------
-- a lua State Machine
-- Weixu Zhu (Harry) zhuweixu_harry@126.com
-- Version 1.0
-- 		first attempt
------------------------------------------------------
package.path = package.path .. ";math/?.lua"
Vec3 = require("Vector3")
Quaternion = require("Quaternion")

local VNS = {CLASSVNS = true}
VNS.__index = VNS

function VNS:new(option)
	return self:create(option)
end

function VNS:create(option)
	local instance = {}
	setmetatable(instance, self)

	instance.idS = option.idS
	instance.locV3 = option.locV3 or Vec3:create()
	instance.dirQ = option.dirQ or Quaternion:create()
	instance.typeS = option.typeS
	instance.roleS = option.roleS
	instance.state = option.state
	instance.parentS = option.parentS

	instance.childrenVnsT = {}
	instance.childrenN = 0
	instance.childrenRolesVnsTT = {new = {},}

	return instance
end

function VNS:add(_xVns)
	if type(_xVns) == "table" and _xVns.CLASSVNS == true then
		if self.childrenVnsT[_xVns.idS] ~= nil then 
			print("Warning: double add", _xVns.idS) end
		self.childrenVnsT[_xVns.idS] = _xVns
		self.childrenRolesVnsTT.new[_xVns.idS] = _xVns
		_xVns.parentS = self.idS
		_xVns.roleS = "new"
	else
		print("Warning: invalid add")
	end
end

function VNS:remove(idS)
	if self.childrenVnsT[idS] ~= nil then
		self.childrenVnsT[idS].parentS = nil
		self.childrenVnsT[idS] = nil
		for i, vVnsT in pairs(vns.childrenRolesVnsTT) do
			vVnsT[idS] = nil
		end
	end
end

function VNS:changeRole(idS, newRoleS)
	if self.childrenVnsT[idS] ~= nil then
		local oldRoleS = self.childrenVnsT[idS].roleS
		self.childrenRolesVnsTT[oldRoleS][idS] = nil
		self.childrenVnsT[idS].roleS = newRoleS
		if self.childrenRolesVnsTT[newRoleS] == nil then
			self.childrenRolesVnsTT[newRoleS] = {}
		end
		self.childrenRolesVnsTT[newRoleS][idS] = self.childrenVnsT[idS]
	end
end

return VNS
