--!strict

local RoundLifecycle = {}

export type Phase = "WAITING" | "ACTIVE" | "RESULT" | "RESETTING"
export type Result = "SUCCESS" | "FAILURE"
export type FailureReason = "TIMEOUT" | "DEATH" | "VOID"
export type Rejection =
    "MALFORMED_EVENT"
    | "INVALID_TRANSITION"
    | "GENERATION_MISMATCH"
    | "INVALID_FAILURE_REASON"

export type State = {
    phase: Phase,
    generation: number,
    result: Result?,
    failureReason: FailureReason?,
}

export type Event =
    { type: "START" }
    | { type: "SUCCEED", generation: number }
    | { type: "FAIL", generation: number, reason: FailureReason }
    | { type: "BEGIN_RESET", generation: number }
    | { type: "FINISH_RESET", generation: number }

local failureReasons: { [string]: boolean } = {
    TIMEOUT = true,
    DEATH = true,
    VOID = true,
}

local function makeState(
    phase: Phase,
    generation: number,
    result: Result?,
    failureReason: FailureReason?
): State
    return table.freeze({
        phase = phase,
        generation = generation,
        result = result,
        failureReason = failureReason,
    }) :: State
end

local function reject(state: State, reason: Rejection): (State, boolean, Rejection)
    return state, false, reason
end

local function isGeneration(value: any): boolean
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

function RoundLifecycle.new(): State
    return makeState("WAITING", 0, nil, nil)
end

function RoundLifecycle.transition(state: State, event: Event): (State, boolean, Rejection?)
    local rawEvent = event :: any
    if type(rawEvent) ~= "table" or type(rawEvent.type) ~= "string" then
        return reject(state, "MALFORMED_EVENT")
    end

    local eventType = rawEvent.type
    if eventType == "START" then
        if rawEvent.generation ~= nil then
            return reject(state, "MALFORMED_EVENT")
        end
        if state.phase ~= "WAITING" then
            return reject(state, "INVALID_TRANSITION")
        end

        return makeState("ACTIVE", state.generation + 1, nil, nil), true, nil
    end

    if
        eventType ~= "SUCCEED"
        and eventType ~= "FAIL"
        and eventType ~= "BEGIN_RESET"
        and eventType ~= "FINISH_RESET"
    then
        return reject(state, "MALFORMED_EVENT")
    end

    if not isGeneration(rawEvent.generation) then
        return reject(state, "MALFORMED_EVENT")
    end
    if rawEvent.generation ~= state.generation then
        return reject(state, "GENERATION_MISMATCH")
    end

    if eventType == "SUCCEED" then
        if state.phase ~= "ACTIVE" then
            return reject(state, "INVALID_TRANSITION")
        end

        return makeState("RESULT", state.generation, "SUCCESS", nil), true, nil
    end

    if eventType == "FAIL" then
        if type(rawEvent.reason) ~= "string" or failureReasons[rawEvent.reason] ~= true then
            return reject(state, "INVALID_FAILURE_REASON")
        end
        if state.phase ~= "ACTIVE" then
            return reject(state, "INVALID_TRANSITION")
        end

        return makeState("RESULT", state.generation, "FAILURE", rawEvent.reason :: FailureReason),
            true,
            nil
    end

    if eventType == "BEGIN_RESET" then
        if state.phase ~= "RESULT" then
            return reject(state, "INVALID_TRANSITION")
        end

        return makeState("RESETTING", state.generation, nil, nil), true, nil
    end

    if state.phase ~= "RESETTING" then
        return reject(state, "INVALID_TRANSITION")
    end

    return makeState("WAITING", state.generation, nil, nil), true, nil
end

return table.freeze(RoundLifecycle)
