--!strict

local RoundLifecycle = require("../../src/shared/GameLoop/RoundLifecycle")

type State = RoundLifecycle.State
type Event = RoundLifecycle.Event
type Rejection = RoundLifecycle.Rejection

local function accept(state: State, event: Event): State
    local nextState, accepted, rejection = RoundLifecycle.transition(state, event)
    assert(accepted, `expected event {event.type} to be accepted, got {tostring(rejection)}`)
    assert(rejection == nil, "accepted transition must not have a rejection")
    assert(nextState ~= state, "accepted transition must return a new state")
    assert(table.isfrozen(nextState), "accepted state must be immutable")
    return nextState
end

local function rejectSame(state: State, event: any, expected: Rejection)
    local nextState, accepted, rejection = RoundLifecycle.transition(state, event)
    local eventName = if type(event) == "table" then tostring(event.type) else tostring(event)
    assert(not accepted, `expected event {eventName} to be rejected`)
    assert(rejection == expected, `expected {expected}, got {tostring(rejection)}`)
    assert(nextState == state, "rejected transition must return the original state")
end

local function activeState(): State
    return accept(RoundLifecycle.new(), { type = "START" })
end

local function resultState(): State
    local active = activeState()
    return accept(active, { type = "SUCCEED", generation = active.generation })
end

local function resettingState(): State
    local result = resultState()
    return accept(result, { type = "BEGIN_RESET", generation = result.generation })
end

return {
    suite = "Round lifecycle",
    cases = {
        {
            name = "constructs an immutable waiting generation zero",
            run = function()
                local state = RoundLifecycle.new()
                assert(state.phase == "WAITING", "new lifecycle must wait")
                assert(state.generation == 0, "new lifecycle must use generation zero")
                assert(state.result == nil, "new lifecycle must not carry a result")
                assert(state.failureReason == nil, "new lifecycle must not carry a failure")
                assert(table.isfrozen(state), "new lifecycle must be immutable")
            end,
        },
        {
            name = "starts exactly one clean active generation",
            run = function()
                local waiting = RoundLifecycle.new()
                local active = accept(waiting, { type = "START" })
                assert(active.phase == "ACTIVE", "start must activate the lifecycle")
                assert(active.generation == 1, "first start must create generation one")
                assert(active.result == nil, "active generation must not carry a result")
                assert(active.failureReason == nil, "active generation must not carry a failure")
                rejectSame(active, { type = "START" }, "INVALID_TRANSITION")
            end,
        },
        {
            name = "accepts immediate success only for the active generation",
            run = function()
                local active = activeState()
                local result = accept(active, {
                    type = "SUCCEED",
                    generation = active.generation,
                })
                assert(result.phase == "RESULT", "success must enter result phase")
                assert(result.result == "SUCCESS", "success must set the success result")
                assert(result.failureReason == nil, "success must not set a failure reason")
            end,
        },
        {
            name = "accepts every specified failure reason",
            run = function()
                for _, reason in { "TIMEOUT", "DEATH", "VOID" } do
                    local active = activeState()
                    local result = accept(active, {
                        type = "FAIL",
                        generation = active.generation,
                        reason = reason :: RoundLifecycle.FailureReason,
                    })
                    assert(result.phase == "RESULT", `{reason} failure must enter result phase`)
                    assert(result.result == "FAILURE", `{reason} must set failure result`)
                    assert(result.failureReason == reason, `{reason} must remain available`)
                end
            end,
        },
        {
            name = "keeps the first terminal result immutable",
            run = function()
                local active = activeState()
                local success = accept(active, {
                    type = "SUCCEED",
                    generation = active.generation,
                })
                rejectSame(
                    success,
                    { type = "FAIL", generation = success.generation, reason = "TIMEOUT" },
                    "INVALID_TRANSITION"
                )
                rejectSame(
                    success,
                    { type = "SUCCEED", generation = success.generation },
                    "INVALID_TRANSITION"
                )

                local anotherActive = activeState()
                local failure = accept(anotherActive, {
                    type = "FAIL",
                    generation = anotherActive.generation,
                    reason = "DEATH",
                })
                rejectSame(
                    failure,
                    { type = "SUCCEED", generation = failure.generation },
                    "INVALID_TRANSITION"
                )
                rejectSame(
                    failure,
                    { type = "FAIL", generation = failure.generation, reason = "VOID" },
                    "INVALID_TRANSITION"
                )
            end,
        },
        {
            name = "rejects stale and future generations without mutation",
            run = function()
                local active = activeState()
                rejectSame(
                    active,
                    { type = "SUCCEED", generation = active.generation - 1 },
                    "GENERATION_MISMATCH"
                )
                rejectSame(active, {
                    type = "FAIL",
                    generation = active.generation + 1,
                    reason = "TIMEOUT",
                }, "GENERATION_MISMATCH")
            end,
        },
        {
            name = "accepts only the valid event for each lifecycle phase",
            run = function()
                local states = {
                    WAITING = RoundLifecycle.new(),
                    ACTIVE = activeState(),
                    RESULT = resultState(),
                    RESETTING = resettingState(),
                }
                local validEventByPhase = {
                    WAITING = "START",
                    ACTIVE = "SUCCEED",
                    RESULT = "BEGIN_RESET",
                    RESETTING = "FINISH_RESET",
                }

                for phase, state in states do
                    local events = {
                        { type = "START" },
                        { type = "SUCCEED", generation = state.generation },
                        { type = "FAIL", generation = state.generation, reason = "TIMEOUT" },
                        { type = "BEGIN_RESET", generation = state.generation },
                        { type = "FINISH_RESET", generation = state.generation },
                    }
                    for _, event in events do
                        local nextState, accepted, rejection =
                            RoundLifecycle.transition(state, event :: Event)
                        local shouldAccept = event.type == validEventByPhase[phase]
                            or (phase == "ACTIVE" and event.type == "FAIL")
                        assert(
                            accepted == shouldAccept,
                            `{phase} unexpectedly handled {event.type}`
                        )
                        if shouldAccept then
                            assert(nextState ~= state, `{phase} accepted event must create state`)
                            assert(rejection == nil, `{phase} accepted event must not reject`)
                        else
                            assert(nextState == state, `{phase} rejected event must preserve state`)
                            assert(
                                rejection == "INVALID_TRANSITION",
                                `{phase} wrong event must reject as invalid transition`
                            )
                        end
                    end
                end
            end,
        },
        {
            name = "clears the result during reset and returns to waiting",
            run = function()
                local result = resultState()
                local resetting = accept(result, {
                    type = "BEGIN_RESET",
                    generation = result.generation,
                })
                assert(resetting.phase == "RESETTING", "begin reset must enter resetting")
                assert(
                    resetting.generation == result.generation,
                    "begin reset must preserve generation"
                )
                assert(resetting.result == nil, "begin reset must clear the result")
                assert(resetting.failureReason == nil, "begin reset must clear failure reason")

                local waiting = accept(resetting, {
                    type = "FINISH_RESET",
                    generation = resetting.generation,
                })
                assert(waiting.phase == "WAITING", "finish reset must return to waiting")
                assert(
                    waiting.generation == resetting.generation,
                    "finish reset must preserve generation"
                )
            end,
        },
        {
            name = "replays with one greater generation and no carried result",
            run = function()
                local resetting = resettingState()
                local waiting = accept(resetting, {
                    type = "FINISH_RESET",
                    generation = resetting.generation,
                })
                rejectSame(
                    waiting,
                    { type = "FINISH_RESET", generation = waiting.generation },
                    "INVALID_TRANSITION"
                )

                local replay = accept(waiting, { type = "START" })
                assert(
                    replay.generation == waiting.generation + 1,
                    "replay must increment generation once"
                )
                assert(replay.phase == "ACTIVE", "replay must become active")
                assert(replay.result == nil, "replay must not carry prior result")
                assert(replay.failureReason == nil, "replay must not carry prior failure")
            end,
        },
        {
            name = "rejects malformed and forged event shapes",
            run = function()
                local active = activeState()
                rejectSame(active, nil, "MALFORMED_EVENT")
                rejectSame(active, {}, "MALFORMED_EVENT")
                rejectSame(active, { type = "DECLARE_SUCCESS" }, "MALFORMED_EVENT")
                rejectSame(active, { type = "START", generation = 1 }, "MALFORMED_EVENT")
                rejectSame(active, { type = "SUCCEED" }, "MALFORMED_EVENT")
                rejectSame(active, { type = "SUCCEED", generation = "1" }, "MALFORMED_EVENT")
                rejectSame(active, { type = "SUCCEED", generation = 1.5 }, "MALFORMED_EVENT")
                rejectSame(active, { type = "SUCCEED", generation = -1 }, "MALFORMED_EVENT")
                rejectSame(
                    active,
                    { type = "FAIL", generation = active.generation },
                    "INVALID_FAILURE_REASON"
                )
                rejectSame(
                    active,
                    { type = "FAIL", generation = active.generation, reason = "OTHER" },
                    "INVALID_FAILURE_REASON"
                )
            end,
        },
    },
}
