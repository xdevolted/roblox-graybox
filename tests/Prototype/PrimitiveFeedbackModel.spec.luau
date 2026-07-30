--!strict

local PrimitiveFeedbackModel = require("../../src/client/Prototype/PrimitiveFeedbackModel")

local function activeSnapshot(deadline: any): any
    return {
        phase = "ACTIVE",
        generation = 3,
        result = nil,
        failureReason = nil,
        phaseEndsAt = deadline,
    }
end

local function resultSnapshot(result: any, reason: any, deadline: any): any
    return {
        phase = "RESULT",
        generation = 3,
        result = result,
        failureReason = reason,
        phaseEndsAt = deadline,
    }
end

local function resettingSnapshot(deadline: any): any
    return {
        phase = "RESETTING",
        generation = 3,
        result = nil,
        failureReason = nil,
        phaseEndsAt = deadline,
    }
end

local function assertPreparing(snapshot: any)
    local view = PrimitiveFeedbackModel.present(snapshot, 100, true)
    assert(view.phase == "PREPARING", "expected preparing phase")
    assert(view.text == "PREPARING ROUND...", "expected preparing text")
    assert(view.remainingSeconds == nil, "preparing must not invent a countdown")
end

return {
    suite = "Primitive feedback model",
    cases = {
        {
            name = "PFM-01 rejects waiting missing malformed and cross-phase snapshots",
            run = function()
                assertPreparing(nil)
                assertPreparing({})
                assertPreparing({ phase = "WAITING", generation = 0 })
                assertPreparing({ phase = "UNKNOWN", generation = 1 })
                assertPreparing({ phase = "ACTIVE", generation = 1.5 })
                assertPreparing({
                    phase = "ACTIVE",
                    generation = 1,
                    result = "SUCCESS",
                })
            end,
        },
        {
            name = "PFM-02 maps a coherent active snapshot deterministically",
            run = function()
                local view = PrimitiveFeedbackModel.present(activeSnapshot(111.1), 100, true)
                assert(view.phase == "ACTIVE", "active phase must map")
                assert(view.generation == 3, "active generation must map")
                assert(view.remainingSeconds == 12, "active countdown must ceil")
                assert(view.text:find("ROUND 3", 1, true) ~= nil, "round text must map")
                assert(
                    view.text:find("REACH YOUR GLOWING ZONE", 1, true) ~= nil,
                    "ready objective instruction must map"
                )
                assert(view.text:find("TIME 12", 1, true) ~= nil, "time text must map")
            end,
        },
        {
            name = "PFM-03 applies exact active deadline boundaries",
            run = function()
                assert(
                    PrimitiveFeedbackModel.present(activeSnapshot(100), 100, true).remainingSeconds
                        == 0,
                    "zero boundary must be inclusive"
                )
                assert(
                    PrimitiveFeedbackModel.present(activeSnapshot(120), 100, true).remainingSeconds
                        == 20,
                    "twenty boundary must be inclusive"
                )
                assert(
                    PrimitiveFeedbackModel.present(activeSnapshot(99.9), 100, true).remainingSeconds
                        == 0,
                    "expired active deadline must render zero"
                )
                assert(
                    PrimitiveFeedbackModel.present(activeSnapshot(120.01), 100, true).remainingSeconds
                        == nil,
                    "future active deadline above maximum must be omitted"
                )
            end,
        },
        {
            name = "PFM-04 uses only the explicit objective readiness input",
            run = function()
                local ready = PrimitiveFeedbackModel.present(activeSnapshot(110), 100, true)
                local syncing = PrimitiveFeedbackModel.present(activeSnapshot(110), 100, false)
                local missing = PrimitiveFeedbackModel.present(activeSnapshot(110), 100, nil)
                local malformed = PrimitiveFeedbackModel.present(activeSnapshot(110), 100, "ready")

                assert(
                    ready.text:find("REACH YOUR GLOWING ZONE", 1, true) ~= nil,
                    "literal true must map ready instruction"
                )
                for _, view in { syncing, missing, malformed } do
                    assert(
                        view.text:find("OBJECTIVE SYNCING...", 1, true) ~= nil,
                        "non-true readiness must map syncing"
                    )
                end
            end,
        },
        {
            name = "PFM-05 maps success and the result interval",
            run = function()
                local view = PrimitiveFeedbackModel.present(
                    resultSnapshot("SUCCESS", nil, 101.2),
                    100,
                    false
                )
                assert(view.phase == "RESULT", "success must map result phase")
                assert(view.tone == "SUCCESS", "success tone must map")
                assert(view.remainingSeconds == 2, "success interval must ceil")
                assert(view.text == "SUCCESS\nNEXT ROUND IN 2", "success text must be exact")
            end,
        },
        {
            name = "PFM-06 maps every approved failure reason",
            run = function()
                local expected = {
                    TIMEOUT = "FAILURE — TIMEOUT",
                    DEATH = "FAILURE — DEATH",
                    VOID = "FAILURE — FELL",
                }
                for reason, headline in expected do
                    local view = PrimitiveFeedbackModel.present(
                        resultSnapshot("FAILURE", reason, 101),
                        100,
                        true
                    )
                    assert(view.tone == "FAILURE", "failure tone must map")
                    assert(
                        view.text == `{headline}\nNEXT ROUND IN 1`,
                        `failure text must map {reason}`
                    )
                end
            end,
        },
        {
            name = "PFM-07 tolerates a missing failure reason and rejects contradictions",
            run = function()
                local generic =
                    PrimitiveFeedbackModel.present(resultSnapshot("FAILURE", nil, 101), 100, true)
                assert(generic.text == "FAILURE\nNEXT ROUND IN 1", "missing reason is generic")

                assertPreparing(resultSnapshot("FAILURE", "OTHER", 101))
                assertPreparing(resultSnapshot("SUCCESS", "DEATH", 101))
                assertPreparing(resultSnapshot(nil, nil, 101))
            end,
        },
        {
            name = "PFM-08 maps resetting without terminal carryover",
            run = function()
                local view = PrimitiveFeedbackModel.present(resettingSnapshot(100.4), 100, true)
                assert(view.phase == "RESETTING", "resetting phase must map")
                assert(view.remainingSeconds == 1, "reset countdown must ceil")
                assert(view.text == "RESETTING\nROUND STARTS IN 1", "reset text must be exact")

                local contradictory = resettingSnapshot(100.4)
                contradictory.result = "SUCCESS"
                assertPreparing(contradictory)
            end,
        },
        {
            name = "PFM-09 handles every deadline category for each phase",
            run = function()
                local snapshots = {
                    { make = activeSnapshot, maximum = 20 },
                    {
                        make = function(deadline: any)
                            return resultSnapshot("SUCCESS", nil, deadline)
                        end,
                        maximum = 2,
                    },
                    { make = resettingSnapshot, maximum = 1 },
                }

                for _, descriptor in snapshots do
                    local make = descriptor.make
                    local maximum = descriptor.maximum
                    assert(
                        PrimitiveFeedbackModel.present(make(nil), 100, true).remainingSeconds == nil,
                        "missing deadline must be omitted"
                    )
                    assert(
                        PrimitiveFeedbackModel.present(make("later"), 100, true).remainingSeconds
                            == nil,
                        "nonnumeric deadline must be omitted"
                    )
                    assert(
                        PrimitiveFeedbackModel.present(make(100), 0 / 0, true).remainingSeconds
                            == nil,
                        "NaN current time must be omitted"
                    )
                    assert(
                        PrimitiveFeedbackModel.present(make(math.huge), 100, true).remainingSeconds
                            == nil,
                        "infinite deadline must be omitted"
                    )
                    assert(
                        PrimitiveFeedbackModel.present(make(99), 100, true).remainingSeconds == 0,
                        "negative delta must render zero"
                    )
                    assert(
                        PrimitiveFeedbackModel.present(make(100), 100, true).remainingSeconds == 0,
                        "zero boundary must be inclusive"
                    )
                    assert(
                        PrimitiveFeedbackModel.present(make(100 + maximum), 100, true).remainingSeconds
                            == maximum,
                        "maximum boundary must be inclusive"
                    )
                    assert(
                        PrimitiveFeedbackModel.present(make(100 + maximum + 0.01), 100, true).remainingSeconds
                            == nil,
                        "future delta above maximum must be omitted"
                    )
                end
            end,
        },
        {
            name = "PFM-10 carries no prior text through a complete presentation sequence",
            run = function()
                local active = PrimitiveFeedbackModel.present(activeSnapshot(110), 100, true)
                local result = PrimitiveFeedbackModel.present(
                    resultSnapshot("FAILURE", "TIMEOUT", 102),
                    100,
                    true
                )
                local resetting = PrimitiveFeedbackModel.present(resettingSnapshot(101), 100, true)
                local replay = activeSnapshot(120)
                replay.generation = 4
                local replayView = PrimitiveFeedbackModel.present(replay, 100, true)

                assert(active.text:find("FAILURE", 1, true) == nil, "active has no result")
                assert(result.text:find("TIMEOUT", 1, true) ~= nil, "result maps reason")
                assert(resetting.text:find("TIMEOUT", 1, true) == nil, "reset clears prior reason")
                assert(replayView.generation == 4, "replay maps greater generation")
                assert(
                    replayView.text:find("FAILURE", 1, true) == nil,
                    "replay clears prior result"
                )
            end,
        },
        {
            name = "PFM-11 returns equal deterministic frozen view models",
            run = function()
                local first = PrimitiveFeedbackModel.present(activeSnapshot(110), 100, true)
                local second = PrimitiveFeedbackModel.present(activeSnapshot(110), 100, true)
                assert(table.isfrozen(first), "view model must be frozen")
                assert(table.isfrozen(second), "repeated view model must be frozen")
                assert(first.phase == second.phase, "phase must be deterministic")
                assert(first.text == second.text, "text must be deterministic")
                assert(
                    first.remainingSeconds == second.remainingSeconds,
                    "countdown must be deterministic"
                )
            end,
        },
        {
            name = "PFM-12 ignores objective readiness for terminal outcome mapping",
            run = function()
                local successReady =
                    PrimitiveFeedbackModel.present(resultSnapshot("SUCCESS", nil, 101), 100, true)
                local successSyncing =
                    PrimitiveFeedbackModel.present(resultSnapshot("SUCCESS", nil, 101), 100, false)
                local resetReady = PrimitiveFeedbackModel.present(resettingSnapshot(101), 100, true)
                local resetSyncing =
                    PrimitiveFeedbackModel.present(resettingSnapshot(101), 100, false)

                assert(
                    successReady.text == successSyncing.text,
                    "readiness must not alter result mapping"
                )
                assert(
                    resetReady.text == resetSyncing.text,
                    "readiness must not alter reset mapping"
                )
            end,
        },
    },
}
