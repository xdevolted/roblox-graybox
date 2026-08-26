--!strict

local InputController = require(script.Parent.Prototype.InputController)
local DebugHudController = require(script.Parent.Prototype.DebugHudController)
local RainController = require(script.Parent.Prototype.RainController)

InputController.start()
DebugHudController.start()
RainController.start()

print("[RobloxGraybox] Client bootstrap ready")
