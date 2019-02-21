VNS = require("VNS")

vns = VNS:new{
	idS = "test",
}

vns2 = VNS:new{
	idS = "test2",
}

vns3 = VNS:new{
	idS = "test3",
}

vns:add(vns2)
vns:add(vns3, "dancer2")
--vns:changeRole("test3","dancer")
--vns:remove("test2")

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
