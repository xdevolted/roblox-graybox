--!strict

local Prototype = script.Parent.Prototype

local InputController = require(Prototype.InputController)
local DebugHudController = require(Prototype.DebugHudController)

InputController.start()
DebugHudController.start()

print("[RobloxGraybox] Client bootstrap ready")
