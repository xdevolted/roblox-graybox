--!strict

local PlayerRoundAdapter = require(script.Parent.GameLoop.PlayerRoundAdapter)
local SafeSpawnObjectiveAdapter = require(script.Parent.GameLoop.SafeSpawnObjectiveAdapter)

local _playerRoundController = PlayerRoundAdapter.start()
local _safeSpawnObjectiveController = SafeSpawnObjectiveAdapter.start()

print("[RobloxGraybox] Server bootstrap ready")
