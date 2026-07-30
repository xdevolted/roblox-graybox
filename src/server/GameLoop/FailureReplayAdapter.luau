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
    repositionObjective: (player: any) -> (any?, any),
}

type LoadComplete = (succeeded: boolean, message: string?) -> ()
type LoadCharacterAsync = (player: any, complete: LoadComplete) -> ()
type SetAttribute = (player: any, name: string, value: any) -> ()
type ReportFailure = (message: string) -> ()

type Observation = {
    active: boolean,
    characterConnection: any?,
    humanoidConnection: any?,
    character: any?,
    humanoid: any?,
    handle: any?,
    generation: number?,
    activeEndsAt: number?,
    resultEndsAt: number?,
    resetEndsAt: number?,
    publishedEndsAt: number?,
    attemptedHandle: any?,
    attemptedGeneration: number?,
    resetAttempted: boolean,
    resetToken: any?,
    resetPriorCharacter: any?,
    replacementCharacter: any?,
    loadToken: any?,
    loadPending: boolean,
    loadSucceeded: boolean,
    resetFailed: boolean,
    finishAttempted: boolean,
    initialLoadRequested: boolean,
}

local FailureReplayAdapter = {}

local ROUND_DURATION_SECONDS = 20
local RESULT_DURATION_SECONDS = 2
local RESET_DURATION_SECONDS = 1
local VOID_Y = -20
local PHASE_ENDS_AT_ATTRIBUTE = "GrayboxPhaseEndsAt"

export type Dependencies = {
    players: any?,
    heartbeat: any?,
    now: (() -> number)?,
    findHumanoid: ((character: any) -> any?)?,
    getCharacterY: ((character: any) -> number?)?,
    loadCharacterAsync: LoadCharacterAsync?,
    setAttribute: SetAttribute?,
    reportFailure: ReportFailure?,
}

export type Controller = {
    stop: () -> (),
}

local function defaultNow(): number
    return game:GetService("Workspace"):GetServerTimeNow()
end

local function defaultFindHumanoid(character: any): any?
    return character:FindFirstChildOfClass("Humanoid")
end

local function defaultGetCharacterY(character: any): number?
    return character:GetPivot().Position.Y
end

local function defaultLoadCharacterAsync(player: any, complete: LoadComplete)
    task.spawn(function()
        local succeeded, message = pcall(function()
            player:LoadCharacterAsync()
        end)
        complete(succeeded, if succeeded then nil else tostring(message))
    end)
end

local function defaultSetAttribute(player: any, name: string, value: any)
    player:SetAttribute(name, value)
end

local function defaultReportFailure(message: string)
    warn(`[RobloxGraybox] {message}`)
end

local function disconnect(connection: any?)
    if connection ~= nil then
        connection:Disconnect()
    end
end

local function isGeneration(value: any): boolean
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

function FailureReplayAdapter.start(
    roundController: RoundController,
    objectiveController: ObjectiveController,
    dependencies: Dependencies?
): Controller
    local provided: Dependencies = dependencies or {}
    local players = provided.players or game:GetService("Players")
    local heartbeat = provided.heartbeat or game:GetService("RunService").Heartbeat
    local now: () -> number = provided.now or defaultNow
    local findHumanoid: (character: any) -> any? = provided.findHumanoid or defaultFindHumanoid
    local getCharacterY: (character: any) -> number? = provided.getCharacterY
        or defaultGetCharacterY
    local loadCharacterAsync: LoadCharacterAsync = provided.loadCharacterAsync
        or defaultLoadCharacterAsync
    local setAttribute: SetAttribute = provided.setAttribute or defaultSetAttribute
    local reportFailure: ReportFailure = provided.reportFailure or defaultReportFailure

    local observations: { [any]: Observation } = {}
    local stopped = false
    -- This adapter is the sole runtime owner of CharacterAutoLoads while active.
    -- Other systems must not change the global property before stop restores it.
    local previousCharacterAutoLoads = players.CharacterAutoLoads
    players.CharacterAutoLoads = false

    local function writePhaseEndsAt(player: any, observation: Observation, value: number?)
        if observation.publishedEndsAt == value then
            return
        end
        observation.publishedEndsAt = value
        setAttribute(player, PHASE_ENDS_AT_ATTRIBUTE, value)
    end

    local function clearGenerationWork(observation: Observation)
        observation.activeEndsAt = nil
        observation.resultEndsAt = nil
        observation.resetEndsAt = nil
        observation.attemptedHandle = nil
        observation.attemptedGeneration = nil
        observation.resetAttempted = false
        observation.resetToken = nil
        observation.resetPriorCharacter = nil
        observation.replacementCharacter = nil
        observation.loadToken = nil
        observation.loadPending = false
        observation.loadSucceeded = false
        observation.resetFailed = false
        observation.finishAttempted = false
    end

    local function setGeneration(observation: Observation, handle: any, generation: number)
        if observation.handle == handle and observation.generation == generation then
            return
        end
        observation.handle = handle
        observation.generation = generation
        clearGenerationWork(observation)
    end

    local function currentActiveContext(player: any): (any?, number?)
        local handle = roundController.getSessionHandle(player)
        local state = roundController.getState(player)
        if
            handle == nil
            or state == nil
            or state.phase ~= "ACTIVE"
            or not isGeneration(state.generation)
        then
            return nil, nil
        end
        return handle, state.generation
    end

    local function attemptFailure(
        player: any,
        observation: Observation,
        reason: "TIMEOUT" | "DEATH" | "VOID"
    )
        if stopped or not observation.active or observations[player] ~= observation then
            return
        end

        local handle, generation = currentActiveContext(player)
        if handle == nil or generation == nil then
            return
        end
        if
            observation.attemptedHandle == handle
            and observation.attemptedGeneration == generation
        then
            return
        end

        observation.attemptedHandle = handle
        observation.attemptedGeneration = generation
        roundController.applyServerEvent(player, handle, {
            type = "FAIL",
            generation = generation,
            reason = reason,
        })
    end

    local function bindHumanoid(
        player: any,
        observation: Observation,
        character: any,
        humanoid: any
    )
        if
            stopped
            or not observation.active
            or observations[player] ~= observation
            or player.Character ~= character
        then
            return
        end

        disconnect(observation.humanoidConnection)
        observation.humanoidConnection = nil
        observation.humanoid = humanoid
        observation.humanoidConnection = humanoid.Died:Connect(function()
            if
                stopped
                or not observation.active
                or observations[player] ~= observation
                or observation.character ~= character
                or observation.humanoid ~= humanoid
                or player.Character ~= character
            then
                return
            end
            attemptFailure(player, observation, "DEATH")
        end)
    end

    local function bindCharacter(player: any, observation: Observation, character: any?)
        if
            stopped
            or not observation.active
            or observations[player] ~= observation
            or player.Character ~= character
        then
            return
        end

        disconnect(observation.humanoidConnection)
        observation.humanoidConnection = nil
        observation.humanoid = nil
        observation.character = character

        if
            observation.resetToken ~= nil
            and character ~= nil
            and character ~= observation.resetPriorCharacter
        then
            observation.replacementCharacter = character
        end

        if character ~= nil then
            local humanoid = findHumanoid(character)
            if humanoid ~= nil then
                bindHumanoid(player, observation, character, humanoid)
            end
        end
    end

    local function refreshCharacter(player: any, observation: Observation)
        local character = player.Character
        if observation.character ~= character then
            bindCharacter(player, observation, character)
            return
        end
        if character ~= nil and observation.humanoid == nil then
            local humanoid = findHumanoid(character)
            if humanoid ~= nil then
                bindHumanoid(player, observation, character, humanoid)
            end
        end
    end

    local function requestInitialCharacter(player: any, observation: Observation)
        if observation.initialLoadRequested or player.Character ~= nil then
            return
        end
        observation.initialLoadRequested = true
        local token = {}
        observation.loadToken = token
        observation.loadPending = true
        loadCharacterAsync(player, function(succeeded: boolean, message: string?)
            if
                stopped
                or not observation.active
                or observations[player] ~= observation
                or observation.loadToken ~= token
            then
                return
            end
            observation.loadPending = false
            observation.loadSucceeded = succeeded
            if not succeeded then
                reportFailure(
                    `initial Character load failed for {player.Name}: {message or "unknown error"}`
                )
            end
        end)
    end

    local function beginReset(
        player: any,
        observation: Observation,
        handle: any,
        generation: number,
        currentTime: number
    )
        if observation.resetToken ~= nil then
            return
        end

        local token = {}
        observation.resetToken = token
        observation.resetEndsAt = currentTime + RESET_DURATION_SECONDS
        observation.resetPriorCharacter = player.Character
        observation.replacementCharacter = nil
        observation.loadToken = token
        observation.loadPending = false
        observation.loadSucceeded = false
        observation.resetFailed = false
        observation.finishAttempted = false
        writePhaseEndsAt(player, observation, observation.resetEndsAt)

        disconnect(observation.humanoidConnection)
        observation.humanoidConnection = nil
        observation.humanoid = nil

        local assignment, repositionRejection = objectiveController.repositionObjective(player)
        if assignment == nil then
            observation.resetFailed = true
            reportFailure(
                `objective reposition failed for {player.Name}: {tostring(repositionRejection)}`
            )
            return
        end

        observation.loadPending = true
        loadCharacterAsync(player, function(succeeded: boolean, message: string?)
            if
                stopped
                or not observation.active
                or observations[player] ~= observation
                or observation.resetToken ~= token
                or observation.loadToken ~= token
                or observation.handle ~= handle
                or observation.generation ~= generation
            then
                return
            end

            observation.loadPending = false
            observation.loadSucceeded = succeeded
            if not succeeded then
                observation.resetFailed = true
                reportFailure(
                    `reset Character load failed for {player.Name}: {message or "unknown error"}`
                )
            end
        end)
    end

    local function completeReset(
        player: any,
        observation: Observation,
        handle: any,
        generation: number,
        currentTime: number
    )
        if observation.finishAttempted then
            return
        end
        observation.finishAttempted = true

        local finished = roundController.applyServerEvent(player, handle, {
            type = "FINISH_RESET",
            generation = generation,
        })
        if not finished then
            return
        end

        local started = roundController.applyServerEvent(player, handle, {
            type = "START",
        })
        if not started then
            return
        end

        local startedState = roundController.getState(player)
        if
            startedState == nil
            or startedState.phase ~= "ACTIVE"
            or not isGeneration(startedState.generation)
            or startedState.generation <= generation
        then
            reportFailure(`post-START state was invalid for {player.Name}`)
            return
        end

        setGeneration(observation, handle, startedState.generation)
        observation.activeEndsAt = currentTime + ROUND_DURATION_SECONDS
        writePhaseEndsAt(player, observation, observation.activeEndsAt)
    end

    local function updatePlayer(player: any, observation: Observation)
        if stopped or not observation.active or observations[player] ~= observation then
            return
        end

        refreshCharacter(player, observation)

        local handle = roundController.getSessionHandle(player)
        local state = roundController.getState(player)
        if handle == nil or state == nil or not isGeneration(state.generation) then
            return
        end

        setGeneration(observation, handle, state.generation)
        local currentTime = now()

        if state.phase == "ACTIVE" then
            local activeEndsAt = observation.activeEndsAt
            if activeEndsAt == nil then
                activeEndsAt = currentTime + ROUND_DURATION_SECONDS
                observation.activeEndsAt = activeEndsAt
                writePhaseEndsAt(player, observation, activeEndsAt)
            end
            local activeDeadline: number =
                assert(activeEndsAt, "active deadline must be initialized")
            requestInitialCharacter(player, observation)

            local character = player.Character
            if character ~= nil then
                local characterY = getCharacterY(character)
                if characterY ~= nil and characterY < VOID_Y then
                    attemptFailure(player, observation, "VOID")
                    return
                end
            end
            if currentTime >= activeDeadline then
                attemptFailure(player, observation, "TIMEOUT")
            end
            return
        end

        if state.phase == "RESULT" then
            local resultEndsAt = observation.resultEndsAt
            if resultEndsAt == nil then
                resultEndsAt = currentTime + RESULT_DURATION_SECONDS
                observation.resultEndsAt = resultEndsAt
                writePhaseEndsAt(player, observation, resultEndsAt)
            end
            local resultDeadline: number =
                assert(resultEndsAt, "result deadline must be initialized")
            if currentTime < resultDeadline or observation.resetAttempted then
                return
            end

            observation.resetAttempted = true
            local accepted = roundController.applyServerEvent(player, handle, {
                type = "BEGIN_RESET",
                generation = state.generation,
            })
            if accepted then
                beginReset(player, observation, handle, state.generation, currentTime)
            end
            return
        end

        if state.phase == "RESETTING" then
            local resetEndsAt = observation.resetEndsAt
            if
                resetEndsAt ~= nil
                and currentTime >= resetEndsAt
                and not observation.resetFailed
                and not observation.loadPending
                and observation.loadSucceeded
                and observation.replacementCharacter ~= nil
                and player.Character == observation.replacementCharacter
            then
                completeReset(player, observation, handle, state.generation, currentTime)
            end
            return
        end

        writePhaseEndsAt(player, observation, nil)
    end

    local function initializePlayer(player: any)
        if stopped or observations[player] ~= nil then
            return
        end

        local observation: Observation = {
            active = true,
            characterConnection = nil,
            humanoidConnection = nil,
            character = nil,
            humanoid = nil,
            handle = nil,
            generation = nil,
            activeEndsAt = nil,
            resultEndsAt = nil,
            resetEndsAt = nil,
            publishedEndsAt = nil,
            attemptedHandle = nil,
            attemptedGeneration = nil,
            resetAttempted = false,
            resetToken = nil,
            resetPriorCharacter = nil,
            replacementCharacter = nil,
            loadToken = nil,
            loadPending = false,
            loadSucceeded = false,
            resetFailed = false,
            finishAttempted = false,
            initialLoadRequested = false,
        }
        observations[player] = observation

        observation.characterConnection = player.CharacterAdded:Connect(function(character: any)
            bindCharacter(player, observation, character)
        end)
        bindCharacter(player, observation, player.Character)
    end

    local function invalidateObservation(player: any, observation: Observation)
        observation.active = false
        observation.resetToken = nil
        observation.loadToken = nil
        disconnect(observation.characterConnection)
        disconnect(observation.humanoidConnection)
        observation.characterConnection = nil
        observation.humanoidConnection = nil
        observation.character = nil
        observation.humanoid = nil
        setAttribute(player, PHASE_ENDS_AT_ATTRIBUTE, nil)
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
        invalidateObservation(player, observation)
    end

    local connections = {
        players.PlayerAdded:Connect(initializePlayer),
        players.PlayerRemoving:Connect(removePlayer),
        heartbeat:Connect(function()
            for player, observation in observations do
                local succeeded = pcall(updatePlayer, player, observation)
                if not succeeded then
                    reportFailure(`update failed for {player.Name}`)
                end
            end
        end),
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
        for player, observation in observations do
            table.insert(ownedObservations, {
                player = player,
                observation = observation,
            })
        end
        table.clear(observations)

        for _, owned in ownedObservations do
            invalidateObservation(owned.player, owned.observation)
        end
        players.CharacterAutoLoads = previousCharacterAutoLoads
    end

    return table.freeze({
        stop = stop,
    }) :: Controller
end

return table.freeze(FailureReplayAdapter)
