--!strict

local InputController = require(script.Parent.Prototype.InputController)
local DebugHudController = require(script.Parent.Prototype.DebugHudController)

InputController.start()
DebugHudController.start()

print("[RobloxGraybox] Client bootstrap ready")
