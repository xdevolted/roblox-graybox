--!strict

type LifecycleState = {
    phase: "WAITING" | "ACTIVE" | "RESULT" | "RESETTING",
    generation: number,
    result: ("SUCCESS" | "FAILURE")?,
    failureReason: ("TIMEOUT" | "DEATH" | "VOID")?,
}

type SessionHandle = {}
type Rejection =
    "MALFORMED_EVENT"
    | "INVALID_TRANSITION"
    | "GENERATION_MISMATCH"
    | "INVALID_FAILURE_REASON"
    | "DUPLICATE_PLAYER"
    | "UNKNOWN_PLAYER"
    | "SESSION_MISMATCH"
    | "DESTROYED"

type Publisher = (player: any, handle: SessionHandle, state: LifecycleState?) -> ()
type Registry = {
    initialize: (player: any) -> (SessionHandle?, Rejection?),
    applyServerEvent: (
        player: any,
        handle: SessionHandle,
        event: any
    ) -> (boolean, Rejection?),
    getState: (player: any) -> LifecycleState?,
    remove: (player: any) -> boolean,
    destroy: () -> (),
}
type RegistryFactory = (Publisher) -> Registry
type RegistryModule = {
    new: RegistryFactory,
}

local PlayerRoundAdapter = {}

local ATTRIBUTE_NAMES = {
    phase = "GrayboxRoundPhase",
    generation = "GrayboxRoundGeneration",
    result = "GrayboxRoundResult",
    failureReason = "GrayboxRoundFailureReason",
}

export type Dependencies = {
    players: any?,
    registryFactory: RegistryFactory?,
    setAttribute: ((player: any, name: string, value: any) -> ())?,
}

export type Controller = {
    getSessionHandle: (player: any) -> SessionHandle?,
    getState: (player: any) -> LifecycleState?,
    applyServerEvent: (
        player: any,
        handle: SessionHandle,
        event: any
    ) -> (boolean, Rejection?),
    stop: () -> (),
}

local function defaultRegistryFactory(publisher: Publisher): Registry
    local registryModule: RegistryModule =
        require(game:GetService("ReplicatedStorage").Shared.GameLoop.PlayerRoundRegistry)
    return registryModule.new(publisher)
end

local function defaultSetAttribute(player: any, name: string, value: any)
    player:SetAttribute(name, value)
end

function PlayerRoundAdapter.start(dependencies: Dependencies?): Controller
    local provided: Dependencies = dependencies or {}
    local players = provided.players or game:GetService("Players")
    local registryFactory: RegistryFactory = provided.registryFactory or defaultRegistryFactory
    local setAttribute = provided.setAttribute or defaultSetAttribute

    local handles: { [any]: SessionHandle } = {}
    local initializing: { [any]: boolean } = {}
    local destroying = false
    local stopped = false

    local function publishSnapshot(player: any, handle: SessionHandle, state: LifecycleState?)
        if stopped and not destroying then
            return
        end

        local currentHandle = handles[player]
        if state ~= nil then
            if currentHandle == nil then
                if initializing[player] ~= true then
                    return
                end
                handles[player] = handle
            elseif currentHandle ~= handle then
                return
            end
        elseif currentHandle ~= handle then
            return
        end

        setAttribute(player, ATTRIBUTE_NAMES.phase, if state == nil then nil else state.phase)
        setAttribute(
            player,
            ATTRIBUTE_NAMES.generation,
            if state == nil then nil else state.generation
        )
        setAttribute(player, ATTRIBUTE_NAMES.result, if state == nil then nil else state.result)
        setAttribute(
            player,
            ATTRIBUTE_NAMES.failureReason,
            if state == nil then nil else state.failureReason
        )

        if state == nil then
            handles[player] = nil
        end
    end

    local registry = registryFactory(publishSnapshot)

    local function initializePlayer(player: any)
        if stopped or handles[player] ~= nil or initializing[player] == true then
            return
        end

        initializing[player] = true
        local handle = registry.initialize(player)
        initializing[player] = nil
        if handle ~= nil and handles[player] == nil then
            handles[player] = handle
        end
    end

    local function removePlayer(player: any)
        if stopped or handles[player] == nil then
            return
        end
        registry.remove(player)
        handles[player] = nil
    end

    local connections = {
        players.PlayerAdded:Connect(initializePlayer),
        players.PlayerRemoving:Connect(removePlayer),
    }

    for _, player in players:GetPlayers() do
        initializePlayer(player)
    end

    local function getSessionHandle(player: any): SessionHandle?
        if stopped then
            return nil
        end
        return handles[player]
    end

    local function getState(player: any): LifecycleState?
        if stopped then
            return nil
        end
        return registry.getState(player)
    end

    local function applyServerEvent(
        player: any,
        handle: SessionHandle,
        event: any
    ): (boolean, Rejection?)
        if stopped then
            return false, "DESTROYED"
        end
        return registry.applyServerEvent(player, handle, event)
    end

    local function stop()
        if stopped then
            return
        end
        stopped = true

        for _, connection in connections do
            connection:Disconnect()
        end

        destroying = true
        registry.destroy()
        destroying = false
        table.clear(handles)
        table.clear(initializing)
    end

    return table.freeze({
        getSessionHandle = getSessionHandle,
        getState = getState,
        applyServerEvent = applyServerEvent,
        stop = stop,
    }) :: Controller
end

return table.freeze(PlayerRoundAdapter)
