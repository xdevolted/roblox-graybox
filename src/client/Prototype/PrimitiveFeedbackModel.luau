--!strict

export type ViewModel = {
    phase: "PREPARING" | "ACTIVE" | "RESULT" | "RESETTING",
    generation: number?,
    tone: "NEUTRAL" | "ACTIVE" | "SUCCESS" | "FAILURE",
    text: string,
    remainingSeconds: number?,
}

local PrimitiveFeedbackModel = {}

local ACTIVE_WINDOW_SECONDS = 20
local RESULT_WINDOW_SECONDS = 2
local RESET_WINDOW_SECONDS = 1

local function isFiniteNumber(value: any): boolean
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isPositiveInteger(value: any): boolean
    return isFiniteNumber(value) and value > 0 and value % 1 == 0
end

local function remainingSeconds(deadline: any, currentTime: any, maximum: number): number?
    if not isFiniteNumber(deadline) or not isFiniteNumber(currentTime) then
        return nil
    end

    local delta = deadline - currentTime
    if delta < 0 then
        return 0
    end
    if delta > maximum then
        return nil
    end
    return math.ceil(delta)
end

local function countdownLine(remaining: number?, numericPrefix: string, syncingText: string): string
    if remaining == nil then
        return syncingText
    end
    return `{numericPrefix} {remaining}`
end

local function preparingView(): ViewModel
    local view: ViewModel = {
        phase = "PREPARING",
        generation = nil,
        tone = "NEUTRAL",
        text = "PREPARING ROUND...",
        remainingSeconds = nil,
    }
    return table.freeze(view)
end

function PrimitiveFeedbackModel.present(
    snapshot: any,
    currentTime: any,
    objectiveReady: any
): ViewModel
    if type(snapshot) ~= "table" then
        return preparingView()
    end

    local phase = snapshot.phase
    local generation = snapshot.generation
    if not isPositiveInteger(generation) then
        return preparingView()
    end
    local validGeneration = generation :: number

    if phase == "ACTIVE" then
        if snapshot.result ~= nil or snapshot.failureReason ~= nil then
            return preparingView()
        end

        local remaining = remainingSeconds(snapshot.phaseEndsAt, currentTime, ACTIVE_WINDOW_SECONDS)
        local instruction = if objectiveReady == true
            then "REACH YOUR GLOWING ZONE"
            else "OBJECTIVE SYNCING..."
        local view: ViewModel = {
            phase = "ACTIVE",
            generation = validGeneration,
            tone = "ACTIVE",
            text = table.concat({
                `ROUND {validGeneration}`,
                instruction,
                countdownLine(remaining, "TIME", "TIME SYNCING..."),
            }, "\n"),
            remainingSeconds = remaining,
        }
        return table.freeze(view)
    end

    if phase == "RESULT" then
        local result = snapshot.result
        local failureReason = snapshot.failureReason
        local headline: string
        local tone: "SUCCESS" | "FAILURE"

        if result == "SUCCESS" and failureReason == nil then
            headline = "SUCCESS"
            tone = "SUCCESS"
        elseif result == "FAILURE" then
            tone = "FAILURE"
            if failureReason == nil then
                headline = "FAILURE"
            elseif failureReason == "TIMEOUT" then
                headline = "FAILURE — TIMEOUT"
            elseif failureReason == "DEATH" then
                headline = "FAILURE — DEATH"
            elseif failureReason == "VOID" then
                headline = "FAILURE — FELL"
            else
                return preparingView()
            end
        else
            return preparingView()
        end

        local remaining = remainingSeconds(snapshot.phaseEndsAt, currentTime, RESULT_WINDOW_SECONDS)
        local view: ViewModel = {
            phase = "RESULT",
            generation = validGeneration,
            tone = tone,
            text = table.concat({
                headline,
                countdownLine(remaining, "NEXT ROUND IN", "NEXT ROUND..."),
            }, "\n"),
            remainingSeconds = remaining,
        }
        return table.freeze(view)
    end

    if phase == "RESETTING" then
        if snapshot.result ~= nil or snapshot.failureReason ~= nil then
            return preparingView()
        end

        local remaining = remainingSeconds(snapshot.phaseEndsAt, currentTime, RESET_WINDOW_SECONDS)
        local view: ViewModel = {
            phase = "RESETTING",
            generation = validGeneration,
            tone = "NEUTRAL",
            text = table.concat({
                "RESETTING",
                countdownLine(remaining, "ROUND STARTS IN", "ROUND STARTING..."),
            }, "\n"),
            remainingSeconds = remaining,
        }
        return table.freeze(view)
    end

    return preparingView()
end

return table.freeze(PrimitiveFeedbackModel)
