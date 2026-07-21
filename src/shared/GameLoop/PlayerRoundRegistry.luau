--!strict

local RoundLifecycle = if script ~= nil
    then require(script.Parent.RoundLifecycle)
    else require("./RoundLifecycle")

local PlayerRoundRegistry = {}

export type State = {
    phase: "WAITING" | "ACTIVE" | "RESULT" | "RESETTING",
    generation: number,
    result: ("SUCCESS" | "FAILURE")?,
    failureReason: ("TIMEOUT" | "DEATH" | "VOID")?,
}

type LifecycleRejection =
    "MALFORMED_EVENT"
    | "INVALID_TRANSITION"
    | "GENERATION_MISMATCH"
    | "INVALID_FAILURE_REASON"

local function normalizeLifecycleRejection(rejection: string?): LifecycleRejection?
    if rejection == nil then
        return nil
    end
    if rejection == "MALFORMED_EVENT" then
        return "MALFORMED_EVENT"
    end
    if rejection == "INVALID_TRANSITION" then
        return "INVALID_TRANSITION"
    end
    if rejection == "GENERATION_MISMATCH" then
        return "GENERATION_MISMATCH"
    end
    if rejection == "INVALID_FAILURE_REASON" then
        return "INVALID_FAILURE_REASON"
    end
    error(`unexpected RoundLifecycle rejection: {rejection}`)
end

export type SessionHandle = {}
export type Rejection =
    LifecycleRejection
    | "DUPLICATE_PLAYER"
    | "UNKNOWN_PLAYER"
    | "SESSION_MISMATCH"
    | "DESTROYED"

type Entry = {
    state: State,
    handle: SessionHandle,
}

export type Publisher = (playerKey: any, handle: SessionHandle, state: State?) -> ()

export type Registry = {
    initialize: (playerKey: any) -> (SessionHandle?, Rejection?),
    applyServerEvent: (
        playerKey: any,
        handle: SessionHandle,
        event: any
    ) -> (boolean, Rejection?),
    getState: (playerKey: any) -> State?,
    remove: (playerKey: any) -> boolean,
    destroy: () -> (),
}

function PlayerRoundRegistry.new(publishSnapshot: Publisher): Registry
    local entries: { [any]: Entry } = {}
    local destroyed = false

    local function initialize(playerKey: any): (SessionHandle?, Rejection?)
        if destroyed then
            return nil, "DESTROYED"
        end
        if entries[playerKey] ~= nil then
            return nil, "DUPLICATE_PLAYER"
        end

        local waiting = RoundLifecycle.new()
        local active, accepted, rejection = RoundLifecycle.transition(waiting, { type = "START" })
        assert(accepted and rejection == nil, "initial lifecycle start must be accepted")

        local handle = table.freeze({}) :: SessionHandle
        entries[playerKey] = {
            state = active,
            handle = handle,
        }
        publishSnapshot(playerKey, handle, active)
        return handle, nil
    end

    local function applyServerEvent(
        playerKey: any,
        handle: SessionHandle,
        event: any
    ): (boolean, Rejection?)
        if destroyed then
            return false, "DESTROYED"
        end

        local entry = entries[playerKey]
        if entry == nil then
            return false, "UNKNOWN_PLAYER"
        end
        if entry.handle ~= handle then
            return false, "SESSION_MISMATCH"
        end

        local nextState, accepted, rejection = RoundLifecycle.transition(entry.state, event)
        local lifecycleRejection: LifecycleRejection? = normalizeLifecycleRejection(rejection)
        if not accepted then
            return false, lifecycleRejection
        end
        if lifecycleRejection ~= nil then
            error("accepted RoundLifecycle transition returned a rejection")
        end

        entry.state = nextState
        publishSnapshot(playerKey, handle, nextState)
        return true, nil
    end

    local function getState(playerKey: any): State?
        if destroyed then
            return nil
        end
        local entry = entries[playerKey]
        return if entry == nil then nil else entry.state
    end

    local function remove(playerKey: any): boolean
        if destroyed then
            return false
        end

        local entry = entries[playerKey]
        if entry == nil then
            return false
        end

        entries[playerKey] = nil
        publishSnapshot(playerKey, entry.handle, nil)
        return true
    end

    local function destroy()
        if destroyed then
            return
        end
        destroyed = true

        local removals: { { playerKey: any, handle: SessionHandle } } = {}
        for playerKey, entry in entries do
            table.insert(removals, {
                playerKey = playerKey,
                handle = entry.handle,
            })
        end
        table.clear(entries)

        for _, removal in removals do
            publishSnapshot(removal.playerKey, removal.handle, nil)
        end
    end

    return table.freeze({
        initialize = initialize,
        applyServerEvent = applyServerEvent,
        getState = getState,
        remove = remove,
        destroy = destroy,
    }) :: Registry
end

return table.freeze(PlayerRoundRegistry)
