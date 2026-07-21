--!strict

local PlayerRoundRegistry = require("../../src/shared/GameLoop/PlayerRoundRegistry")

type Publication = {
    player: any,
    handle: PlayerRoundRegistry.SessionHandle,
    state: any,
}

local function newFixture()
    local publications: { Publication } = {}
    local registry = PlayerRoundRegistry.new(function(player, handle, state)
        table.insert(publications, {
            player = player,
            handle = handle,
            state = state,
        })
    end)
    return registry, publications
end

local function initialize(registry: PlayerRoundRegistry.Registry, player: any)
    local handle, rejection = registry.initialize(player)
    assert(handle ~= nil, `expected initialization, got {tostring(rejection)}`)
    assert(rejection == nil, "accepted initialization must not reject")
    return handle :: PlayerRoundRegistry.SessionHandle
end

local function stateOf(registry: PlayerRoundRegistry.Registry, player: any)
    local state = registry.getState(player)
    assert(state ~= nil, "expected player state")
    return state
end

local function accept(
    registry: PlayerRoundRegistry.Registry,
    player: any,
    handle: PlayerRoundRegistry.SessionHandle,
    event: any
)
    local accepted, rejection = registry.applyServerEvent(player, handle, event)
    assert(accepted, `expected accepted event, got {tostring(rejection)}`)
    assert(rejection == nil, "accepted event must not reject")
end

local function reject(
    registry: PlayerRoundRegistry.Registry,
    player: any,
    handle: PlayerRoundRegistry.SessionHandle,
    event: any,
    expected: PlayerRoundRegistry.Rejection
)
    local accepted, rejection = registry.applyServerEvent(player, handle, event)
    assert(not accepted, "expected event rejection")
    assert(rejection == expected, `expected {expected}, got {tostring(rejection)}`)
end

return {
    suite = "Player round registry",
    cases = {
        {
            name = "starts empty and returns no unknown state",
            run = function()
                local registry, publications = newFixture()
                assert(registry.getState({}) == nil, "unknown player must have no state")
                assert(#publications == 0, "empty registry must not publish")
            end,
        },
        {
            name = "initializes one frozen active generation exactly once",
            run = function()
                local registry, publications = newFixture()
                local player = {}
                local handle = initialize(registry, player)
                local state = registry.getState(player)
                assert(state ~= nil and state.phase == "ACTIVE", "player must start active")
                assert(state.generation == 1, "player must start generation one")
                assert(table.isfrozen(state), "registry state must remain immutable")
                assert(#publications == 1, "initialization must publish once")
                assert(publications[1].handle == handle, "publication must use current handle")
                assert(publications[1].state == state, "publication must use stored state")
            end,
        },
        {
            name = "rejects duplicate initialization without side effects",
            run = function()
                local registry, publications = newFixture()
                local player = {}
                local firstHandle = initialize(registry, player)
                local firstState = registry.getState(player)
                local secondHandle, rejection = registry.initialize(player)
                assert(secondHandle == nil, "duplicate must not return a handle")
                assert(rejection == "DUPLICATE_PLAYER", "duplicate must identify rejection")
                assert(registry.getState(player) == firstState, "duplicate must preserve state")
                assert(#publications == 1, "duplicate must not publish")
                assert(publications[1].handle == firstHandle, "original handle must remain")
            end,
        },
        {
            name = "keeps two initialized players isolated",
            run = function()
                local registry = newFixture()
                local first = {}
                local second = {}
                local firstHandle = initialize(registry, first)
                local secondHandle = initialize(registry, second)
                assert(firstHandle ~= secondHandle, "players must have distinct handles")
                assert(
                    registry.getState(first) ~= registry.getState(second),
                    "states must not alias"
                )
            end,
        },
        {
            name = "publishes an accepted result only for its player",
            run = function()
                local registry, publications = newFixture()
                local first = {}
                local second = {}
                local firstHandle = initialize(registry, first)
                initialize(registry, second)
                accept(registry, first, firstHandle, { type = "SUCCEED", generation = 1 })
                assert(stateOf(registry, first).result == "SUCCESS", "first player must succeed")
                assert(
                    stateOf(registry, second).phase == "ACTIVE",
                    "second player must stay active"
                )
                assert(
                    publications[#publications].player == first,
                    "only first player must publish"
                )
            end,
        },
        {
            name = "rejects duplicate terminal observations without republishing",
            run = function()
                local registry, publications = newFixture()
                local player = {}
                local handle = initialize(registry, player)
                accept(registry, player, handle, { type = "SUCCEED", generation = 1 })
                local count = #publications
                reject(
                    registry,
                    player,
                    handle,
                    { type = "FAIL", generation = 1, reason = "TIMEOUT" },
                    "INVALID_TRANSITION"
                )
                assert(#publications == count, "rejected duplicate must not publish")
                assert(stateOf(registry, player).result == "SUCCESS", "first result must remain")
            end,
        },
        {
            name = "rejects stale and future generations without republishing",
            run = function()
                local registry, publications = newFixture()
                local player = {}
                local handle = initialize(registry, player)
                local count = #publications
                reject(
                    registry,
                    player,
                    handle,
                    { type = "SUCCEED", generation = 0 },
                    "GENERATION_MISMATCH"
                )
                reject(
                    registry,
                    player,
                    handle,
                    { type = "SUCCEED", generation = 2 },
                    "GENERATION_MISMATCH"
                )
                assert(#publications == count, "generation mismatches must not publish")
            end,
        },
        {
            name = "rejects unknown and disconnected players",
            run = function()
                local registry = newFixture()
                local player = {}
                local unknown = {}
                local handle = initialize(registry, player)
                reject(
                    registry,
                    unknown,
                    handle,
                    { type = "SUCCEED", generation = 1 },
                    "UNKNOWN_PLAYER"
                )
                assert(registry.remove(player), "connected player must remove")
                reject(
                    registry,
                    player,
                    handle,
                    { type = "SUCCEED", generation = 1 },
                    "UNKNOWN_PLAYER"
                )
            end,
        },
        {
            name = "rejects another player or session handle",
            run = function()
                local registry, publications = newFixture()
                local first = {}
                local second = {}
                local firstHandle = initialize(registry, first)
                local secondHandle = initialize(registry, second)
                local count = #publications
                reject(
                    registry,
                    first,
                    secondHandle,
                    { type = "SUCCEED", generation = 1 },
                    "SESSION_MISMATCH"
                )
                reject(
                    registry,
                    second,
                    firstHandle,
                    { type = "SUCCEED", generation = 1 },
                    "SESSION_MISMATCH"
                )
                assert(#publications == count, "wrong handles must not publish")
            end,
        },
        {
            name = "removes once and invalidates the session",
            run = function()
                local registry, publications = newFixture()
                local player = {}
                local handle = initialize(registry, player)
                assert(registry.remove(player), "first remove must succeed")
                assert(not registry.remove(player), "second remove must be a no-op")
                assert(registry.getState(player) == nil, "removed state must disappear")
                assert(
                    #publications == 2 and publications[2].state == nil,
                    "remove must publish once"
                )
                reject(
                    registry,
                    player,
                    handle,
                    { type = "SUCCEED", generation = 1 },
                    "UNKNOWN_PLAYER"
                )
            end,
        },
        {
            name = "rejects a delayed callback from a replaced session",
            run = function()
                local registry, publications = newFixture()
                local player = {}
                local oldHandle = initialize(registry, player)
                assert(registry.remove(player), "old session must remove")
                local newHandle = initialize(registry, player)
                local count = #publications
                reject(
                    registry,
                    player,
                    oldHandle,
                    { type = "SUCCEED", generation = 1 },
                    "SESSION_MISMATCH"
                )
                assert(stateOf(registry, player).phase == "ACTIVE", "replacement must stay active")
                assert(newHandle ~= oldHandle, "replacement must get a new handle")
                assert(#publications == count, "old callback must not publish")
            end,
        },
        {
            name = "resets and replays with one clean greater generation",
            run = function()
                local registry = newFixture()
                local player = {}
                local handle = initialize(registry, player)
                accept(
                    registry,
                    player,
                    handle,
                    { type = "FAIL", generation = 1, reason = "DEATH" }
                )
                accept(registry, player, handle, { type = "BEGIN_RESET", generation = 1 })
                accept(registry, player, handle, { type = "FINISH_RESET", generation = 1 })
                accept(registry, player, handle, { type = "START" })
                local state = registry.getState(player)
                assert(
                    state.phase == "ACTIVE" and state.generation == 2,
                    "replay must be generation two"
                )
                assert(state.result == nil and state.failureReason == nil, "replay must be clean")
            end,
        },
        {
            name = "rejects duplicate reset finish and replay events",
            run = function()
                local registry, publications = newFixture()
                local player = {}
                local handle = initialize(registry, player)
                accept(registry, player, handle, { type = "SUCCEED", generation = 1 })
                accept(registry, player, handle, { type = "BEGIN_RESET", generation = 1 })
                local count = #publications
                reject(
                    registry,
                    player,
                    handle,
                    { type = "BEGIN_RESET", generation = 1 },
                    "INVALID_TRANSITION"
                )
                accept(registry, player, handle, { type = "FINISH_RESET", generation = 1 })
                reject(
                    registry,
                    player,
                    handle,
                    { type = "FINISH_RESET", generation = 1 },
                    "INVALID_TRANSITION"
                )
                accept(registry, player, handle, { type = "START" })
                reject(registry, player, handle, { type = "START" }, "INVALID_TRANSITION")
                assert(#publications == count + 2, "only finish and replay may publish")
            end,
        },
        {
            name = "rejects malformed events and invalid failures",
            run = function()
                local registry, publications = newFixture()
                local player = {}
                local handle = initialize(registry, player)
                local count = #publications
                reject(registry, player, handle, nil, "MALFORMED_EVENT")
                reject(
                    registry,
                    player,
                    handle,
                    { type = "FAIL", generation = 1, reason = "OTHER" },
                    "INVALID_FAILURE_REASON"
                )
                assert(#publications == count, "invalid events must not publish")
            end,
        },
        {
            name = "destroys all players and rejects later operations",
            run = function()
                local registry, publications = newFixture()
                local first = {}
                local second = {}
                local firstHandle = initialize(registry, first)
                initialize(registry, second)
                registry.destroy()
                registry.destroy()
                assert(
                    registry.getState(first) == nil and registry.getState(second) == nil,
                    "destroy must clear states"
                )
                assert(#publications == 4, "destroy must publish one removal per player")
                local handle, rejection = registry.initialize({})
                assert(
                    handle == nil and rejection == "DESTROYED",
                    "destroyed registry must reject initialize"
                )
                reject(
                    registry,
                    first,
                    firstHandle,
                    { type = "SUCCEED", generation = 1 },
                    "DESTROYED"
                )
            end,
        },
        {
            name = "publishes only accepted immutable state identities",
            run = function()
                local registry, publications = newFixture()
                local player = {}
                local handle = initialize(registry, player)
                accept(registry, player, handle, { type = "SUCCEED", generation = 1 })
                local count = #publications
                reject(
                    registry,
                    player,
                    handle,
                    { type = "SUCCEED", generation = 1 },
                    "INVALID_TRANSITION"
                )
                assert(#publications == count, "rejection must not publish")
                for _, publication in publications do
                    if publication.state ~= nil then
                        assert(
                            table.isfrozen(publication.state),
                            "published state must be immutable"
                        )
                    end
                end
                assert(
                    publications[#publications].state == registry.getState(player),
                    "published identity must be stored"
                )
            end,
        },
    },
}
