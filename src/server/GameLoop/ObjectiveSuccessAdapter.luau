--!strict

type LifecycleState = {
    phase: "WAITING" | "ACTIVE" | "RESULT" | "RESETTING",
    generation: number,
    result: ("SUCCESS" | "FAILURE")?,
    failureReason: ("TIMEOUT" | "DEATH" | "VOID")?,
}

type RoundController = {
    getSessionHandle: (player: any) -> any?,
    getState: (player: any) -> LifecycleState?,
    applyServerEvent: (player: any, handle: any, event: any) -> (boolean, any),
}

type ObjectiveController = {
    getObjective: (player: any) -> any?,
}

type IsBasePart = (value: any) -> boolean
type IsDescendantOf = (part: any, ancestor: any) -> boolean
type FindHumanoid = (character: any) -> any?

type Observation = {
    active: boolean,
    objective: any?,
    characterConnection: any?,
    objectiveConnection: any?,
    attemptedHandle: any?,
    attemptedGeneration: number?,
}

local ObjectiveSuccessAdapter = {}

export type Dependencies = {
    players: any?,
    isBasePart: ((value: any) -> boolean)?,
    isDescendantOf: ((part: any, ancestor: any) -> boolean)?,
    findHumanoid: ((character: any) -> any?)?,
}

export type Controller = {
    stop: () -> (),
}

local function defaultIsBasePart(value: any): boolean
    return typeof(value) == "Instance" and value:IsA("BasePart")
end

local function defaultIsDescendantOf(part: any, ancestor: any): boolean
    return part:IsDescendantOf(ancestor)
end

local function defaultFindHumanoid(character: any): any?
    return character:FindFirstChildOfClass("Humanoid")
end

local function isGeneration(value: any): boolean
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function disconnect(connection: any?)
    if connection ~= nil then
        connection:Disconnect()
    end
end

function ObjectiveSuccessAdapter.start(
    roundController: RoundController,
    objectiveController: ObjectiveController,
    dependencies: Dependencies?
): Controller
    local provided: Dependencies = dependencies or {}
    local players = provided.players or game:GetService("Players")
    local isBasePart: IsBasePart = provided.isBasePart or defaultIsBasePart
    local isDescendantOf: IsDescendantOf = provided.isDescendantOf or defaultIsDescendantOf
    local findHumanoid: FindHumanoid = provided.findHumanoid or defaultFindHumanoid

    local observations: { [any]: Observation } = {}
    local stopped = false

    local function invalidateObservation(observation: Observation)
        observation.active = false
        disconnect(observation.characterConnection)
        disconnect(observation.objectiveConnection)
        observation.characterConnection = nil
        observation.objectiveConnection = nil
        observation.objective = nil
        observation.attemptedHandle = nil
        observation.attemptedGeneration = nil
    end

    local function handleTouch(player: any, observation: Observation, objective: any, part: any)
        if
            stopped
            or not observation.active
            or observations[player] ~= observation
            or observation.objective ~= objective
            or objectiveController.getObjective(player) ~= objective
            or not isBasePart(part)
        then
            return
        end

        local character = player.Character
        if character == nil or not isDescendantOf(part, character) then
            return
        end

        local humanoid = findHumanoid(character)
        if humanoid == nil or type(humanoid.Health) ~= "number" or humanoid.Health <= 0 then
            return
        end

        local handle = roundController.getSessionHandle(player)
        local state = roundController.getState(player)
        if
            handle == nil
            or state == nil
            or state.phase ~= "ACTIVE"
            or not isGeneration(state.generation)
        then
            return
        end

        local generation = state.generation
        if
            observation.attemptedHandle == handle
            and observation.attemptedGeneration == generation
        then
            return
        end

        observation.attemptedHandle = handle
        observation.attemptedGeneration = generation
        roundController.applyServerEvent(player, handle, {
            type = "SUCCEED",
            generation = generation,
        })
    end

    local function bindObjective(player: any, observation: Observation)
        if stopped or not observation.active or observations[player] ~= observation then
            return
        end

        local objective = objectiveController.getObjective(player)
        if observation.objective == objective and observation.objectiveConnection ~= nil then
            return
        end

        disconnect(observation.objectiveConnection)
        observation.objectiveConnection = nil
        observation.objective = objective

        if objective ~= nil then
            observation.objectiveConnection = objective.Touched:Connect(function(part: any)
                handleTouch(player, observation, objective, part)
            end)
        end
    end

    local function initializePlayer(player: any)
        if stopped or observations[player] ~= nil then
            return
        end

        local observation: Observation = {
            active = true,
            objective = nil,
            characterConnection = nil,
            objectiveConnection = nil,
            attemptedHandle = nil,
            attemptedGeneration = nil,
        }
        observations[player] = observation

        observation.characterConnection = player.CharacterAdded:Connect(function()
            bindObjective(player, observation)
        end)
        bindObjective(player, observation)
    end

    local function removePlayer(player: any)
        if stopped then
            return
        end

        local observation = observations[player]
        if observation == nil then
            return
        end

        observations[player] = nil
        invalidateObservation(observation)
    end

    local connections = {
        players.PlayerAdded:Connect(initializePlayer),
        players.PlayerRemoving:Connect(removePlayer),
    }

    for _, player in players:GetPlayers() do
        initializePlayer(player)
    end

    local function stop()
        if stopped then
            return
        end
        stopped = true

        for _, connection in connections do
            connection:Disconnect()
        end

        local ownedObservations = {}
        for _, observation in observations do
            table.insert(ownedObservations, observation)
        end
        table.clear(observations)

        for _, observation in ownedObservations do
            invalidateObservation(observation)
        end
    end

    return table.freeze({
        stop = stop,
    }) :: Controller
end

return table.freeze(ObjectiveSuccessAdapter)
