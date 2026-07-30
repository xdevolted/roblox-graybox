--!strict

local PlayerRoundAdapter = require(script.Parent.GameLoop.PlayerRoundAdapter)
local SafeSpawnObjectiveAdapter = require(script.Parent.GameLoop.SafeSpawnObjectiveAdapter)
local ObjectiveSuccessAdapter = require(script.Parent.GameLoop.ObjectiveSuccessAdapter)
local FailureReplayAdapter = require(script.Parent.GameLoop.FailureReplayAdapter)

local _playerRoundController = PlayerRoundAdapter.start()
local _safeSpawnObjectiveController = SafeSpawnObjectiveAdapter.start()
local _objectiveSuccessController =
    ObjectiveSuccessAdapter.start(_playerRoundController, _safeSpawnObjectiveController)
local _failureReplayController =
    FailureReplayAdapter.start(_playerRoundController, _safeSpawnObjectiveController)

print("[RobloxGraybox] Server bootstrap ready")
