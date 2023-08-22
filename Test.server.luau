--!strict
-- Services
-- Packages
local Package = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("package"))
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Maid"))
-- Modules
-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
Package.init(Maid.new())

local ElevatorFolder = workspace:WaitForChild("Elevator")
local ElevatorCar = ElevatorFolder:WaitForChild("Car") :: Model
local Floors: {[number]: BasePart} = ElevatorFolder:WaitForChild("Floors"):GetChildren() :: any

Package:SortFloorsByName(Floors)

local elevator = Package:RegisterElevator(ElevatorCar, Floors)
task.wait(10)
elevator:AddFloorToQueue("5")
elevator:AddFloorToQueue("3")
elevator:AddFloorToQueue("4")
elevator:AddFloorToQueue("1")