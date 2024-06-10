--!strict
--!native
local _Package = script
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local ServiceProxy = require(_Packages:WaitForChild("ServiceProxy"))

-- Modules
local Elevator = require(_Package:WaitForChild("Elevator"))

-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class

-- Types
type Maid = Maid.Maid
type Elevator = Elevator.Elevator
export type ElevatorService = {
	__index: ElevatorService,
	_Maid: Maid,
	_IsAlive: boolean,
	_Registry: {[Model]: Elevator},
	SortFloorsByName: (self: ElevatorService, floors: {[number]: BasePart}) -> (),
	RegisterElevator: (self: ElevatorService, car: Model, floors: {[number]: BasePart}) -> Elevator,
	GetElevator: (self: ElevatorService, car: Model) -> Elevator,
	RemoveElevator: (self: ElevatorService, car: Model) -> (),
	Destroy: (self: ElevatorService) -> (),
	new: () -> ElevatorService,
	init: (maid: Maid) -> nil
}

-- Class
local CurrentElevatorService: ElevatorService = nil :: any
local ElevatorService = {} :: ElevatorService
ElevatorService.__index = ElevatorService

function ElevatorService:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	if CurrentElevatorService == self then
		CurrentElevatorService = nil :: any
	end
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function ElevatorService:RegisterElevator(car: Model, floors: {[number]: BasePart}): Elevator
	assert(RunService:IsServer())

	local maid = self._Maid:GiveTask(Maid.new())

	local elevator = self._Maid:GiveTask(Elevator.new(car, floors))

	maid:GiveTask(elevator._OnDestroying:Connect(function()
		self._Registry[car] = nil
		maid:Destroy()
	end))

	self._Registry[car] = elevator
	return elevator
end

function ElevatorService:GetElevator(car: Model): Elevator
	assert(self._Registry[car], `no elevator registered for car {car:GetFullName()}`)
	return self._Registry[car]
end

function ElevatorService:RemoveElevator(car: Model): ()
	local elevator = self:GetElevator(car)
	self._Registry[car] = nil
	elevator:Destroy()
end


function ElevatorService:SortFloorsByName(floors: {[number]: BasePart})
	local function getNumber(name: string): number?
		local initialPattern = name:gsub("%a", ""):gsub("%s", "")
		-- print(`{name} -> {initialPattern}`)
		local numb = tonumber(initialPattern)
		if numb then
			return numb
		else
			local pattern = name:match("%d") or name:match("%d%d") or name:match("%d%d%d") or ""
			-- print(`{name} --> {pattern}`)
			return tonumber(pattern)
		end
	end
	table.sort(floors, function(a: BasePart, b: BasePart): boolean
		local aNum = getNumber(a.Name) or math.huge
		local bNum = getNumber(b.Name) or math.huge
		return aNum < bNum
	end)
end

function ElevatorService.new()

	local self: ElevatorService = setmetatable({}, ElevatorService) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self._Registry = {}
	
	if CurrentElevatorService ~= nil then
		 CurrentElevatorService:Destroy()
		 CurrentElevatorService = nil :: any
	end
	CurrentElevatorService = self

	return self
end

function ElevatorService.init(maid: Maid)

	Elevator.init(maid)
	maid:GiveTask(ElevatorService.new())
	return nil
end

return ServiceProxy(function()
	return CurrentElevatorService or ElevatorService
end)
