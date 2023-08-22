--!strict
local _Package = script.Parent
local _Packages = _Package.Parent

-- Services
local RunService = game:GetService("RunService")

-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local KinematicObjectService = require(_Packages:WaitForChild("KinematicObjectService"))
local Spring = require(_Packages:WaitForChild("Spring"))
local Signal = require(_Packages:WaitForChild("Signal"))

-- Modules
-- Types
-- Constants
local TARGET_MAID_SUFFIX = "_TARGET"
local DEFAULT_DAMPING_RATIO = 1
local DEFAULT_FREQUENCY = 0.25
local SMALL = 0.001
-- Variables
-- References
-- Private Functions
-- Class
-- Types
type Spring = Spring.Spring
type Maid = Maid.Maid
type Signal = Signal.Signal
export type OnFloorInvoke = (floorName: string) -> ()
export type Elevator = {
	__index: Elevator,
	_Maid: Maid,
	_IsAlive: boolean,
	_DampingRatio: number,
	_Frequency: number,
	_DefaultFloor: string,
	_Floors: {[number]: BasePart},
	_IsActive: boolean,
	_OnExitFloorInvoke: OnFloorInvoke,
	_OnArriveFloorInvoke: OnFloorInvoke,
	Queue: {[number]: string},
	BoardingDuration: number,
	DoorDuration: number,
	Spring: Spring,
	Car: Model,
	PassingFloorChime: Sound?,
	ArrivalChime: Sound?,
	MovingSound: Sound?,
	OnCurrentFloorChanged: Signal,
	SetOnArriveFloorInvoke: (self: Elevator, onInvoke: OnFloorInvoke) -> (),
	SetOnExitFloorInvoke: (self: Elevator, onInvoke: OnFloorInvoke) -> (),
	GetFloorNumber: (self: Elevator, floorName: string) -> number,
	GetFloorCFrame: (self: Elevator, floorName: string) -> CFrame,
	GetClosestFloor: (self: Elevator) -> string,
	GetFloorNames: (self: Elevator) -> {[number]: string},
	Destroy: (self: Elevator) -> (),
	_GoTo: (self: Elevator, floorName: string) -> (),
	AddFloorToQueue: (self: Elevator, floorName: string) -> (),
	new: (car: Model, floors: {[number]: BasePart}) -> Elevator,
	init: (maid: Maid) -> nil
}

-- Class
local Elevator = {} :: Elevator
Elevator.__index = Elevator

function Elevator:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function Elevator:GetFloorNumber(floorName: string): number
	for i, v in ipairs(self._Floors) do
		if v.Name == floorName then
			return i
		end
	end
	error(`No floor registered for {floorName} in elevator {self.Car:GetFullName()}`)
end

function Elevator:GetFloorCFrame(floorName: string): CFrame
	local floorNumber = self:GetFloorNumber(floorName)
	local floorPart = self._Floors[floorNumber]
	assert(floorPart)
	return floorPart:GetPivot()
end

function Elevator:GetFloorNames(): {[number]: string}
	local floorNames: {[number]: string} = {}
	for i, floorPart in ipairs(self._Floors) do
		floorNames[i] = floorPart.Name
	end
	return floorNames
end

function Elevator:GetClosestFloor(): string
	local closestFloorName: string?
	local closestDist: number?
	local cf = self.Car:GetPivot()
	for i, v in ipairs(self._Floors) do
		local floorCF = self:GetFloorCFrame(v.Name)
		local dist = (cf.Position - floorCF.Position).Magnitude
		if not closestDist or dist < closestDist then
			closestDist = dist
			closestFloorName = v.Name
		end
	end
	assert(closestDist)
	assert(closestFloorName)
	return closestFloorName
end

function Elevator:AddFloorToQueue(floorName: string)
	if table.find(self.Queue, floorName) then return end

	table.insert(self.Queue, floorName)
	if not self._IsActive then
		self:_GoTo(self.Queue[1])
	end
end

function Elevator:SetOnArriveFloorInvoke(onInvoke: OnFloorInvoke): ()
	self._OnArriveFloorInvoke = onInvoke
end

function Elevator:SetOnExitFloorInvoke(onInvoke: OnFloorInvoke): ()
	self._OnExitFloorInvoke = onInvoke
end

function Elevator:_GoTo(floorName: string): ()
	if self._IsActive then return end
	self._IsActive = true
	-- print(`GoTo {floorName}`)

	local targetMaid = Maid.new()
	self._Maid[TARGET_MAID_SUFFIX] = targetMaid
	task.spawn(function()
		self._OnExitFloorInvoke(self:GetClosestFloor())
	end)

	task.wait(self.DoorDuration)

	assert(self._IsAlive)

	local goalCFrame = self:GetFloorCFrame(floorName)
	
	local initialFloorNumber = self.Spring.Position
	self.Spring:Set(self:GetFloorNumber(floorName))

	local primaryPart = self.Car.PrimaryPart
	assert(primaryPart)

	local startCFrame = primaryPart:GetPivot()

	local prevFloorName: string = self._Floors[math.clamp(math.ceil(initialFloorNumber), 1, #self._Floors)].Name

	if self.MovingSound then
		self.MovingSound:Play()
	end

	targetMaid:GiveTask(RunService.Stepped:Connect(function(time: number, deltaTime: number)
		local currentFloorNumber = self.Spring:Get()
		local closestFloorName = self:GetClosestFloor()

		if closestFloorName ~= prevFloorName then
			prevFloorName = closestFloorName
			self.OnCurrentFloorChanged:Fire(closestFloorName)
			-- print(`current floor {closestFloorName}`)
			if self.PassingFloorChime then
				self.PassingFloorChime:Play()
			end
		end

		local alpha = (currentFloorNumber - initialFloorNumber)/(self.Spring.Goal - initialFloorNumber)
		self.Spring:Step(deltaTime)
		self.Car:PivotTo(startCFrame:Lerp(goalCFrame, alpha))

		if math.abs(self.Spring.Velocity) < SMALL and (goalCFrame.Position - primaryPart:GetPivot().Position).Magnitude < SMALL then
			if self.ArrivalChime then
				self.ArrivalChime:Play()
			end
			if self.MovingSound then
				self.MovingSound:Stop()
			end
			targetMaid:Destroy()
			task.spawn(function()
				self._OnArriveFloorInvoke(floorName)
			end)
			task.wait(self.BoardingDuration)
			assert(self._IsAlive)

			if self.Queue[1] == floorName then
				table.remove(self.Queue, 1)
			else
				local index = table.find(self.Queue, floorName)
				if index then
					table.remove(self.Queue, index)
				end
			end

			self._IsActive = false
			local nextFloorName = self.Queue[1]
			if nextFloorName then
				self:_GoTo(nextFloorName)
			end
		end
	end))
end

function Elevator.new(car: Model, floors: {[number]: BasePart}): Elevator

	assert(car.PrimaryPart, `Car model doesn't have primaryPart {car:GetFullName()}`)

	local self: Elevator = setmetatable({}, Elevator) :: any
	self._IsAlive = true
	self._IsActive = false
	self._Maid = Maid.new()
	self.Car = car
	self.OnCurrentFloorChanged = self._Maid:GiveTask(Signal.new())

	KinematicObjectService:Insert(self.Car)

	self._Maid.bind(self.Car)
	self._Floors = floors
	self.Queue = {}

	local firstFloor = floors[1]
	assert(firstFloor, `You need to have at least 1 floor {car:GetFullName()}`)

	self._DefaultFloor = firstFloor.Name
	self._DampingRatio = DEFAULT_DAMPING_RATIO
	self._Frequency = DEFAULT_FREQUENCY

	self._OnArriveFloorInvoke = function(floorName: string)
		-- print(`arriving at {floorName}`)
	end

	self._OnExitFloorInvoke = function(floorName: string)
		-- print(`exiting {floorName}`)
	end

	self.BoardingDuration = 5
	self.DoorDuration = 1.5

	self.Spring = Spring.new(self._DampingRatio, self._Frequency, 1)

	return self
end

function Elevator.init(maid: Maid)
	if not KinematicObjectService._IsAlive then
		KinematicObjectService.init(maid)
	end
	return nil
end

return Elevator