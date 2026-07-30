--!strict

local RoundLifecycle = require("../../src/shared/GameLoop/RoundLifecycle")
local FailureReplayAdapter = require("../../src/server/GameLoop/FailureReplayAdapter")

type Callback = (value: any) -> ()

local function newSignal(log: { string }, name: string)
    local listeners = {}
    local signal = {}

    function signal:Connect(callback: Callback)
        table.insert(log, `connect:{name}`)
        local listener = {
            active = true,
            callback = callback,
        }
        table.insert(listeners, listener)
        local connection = {}
        function connection.Disconnect(_connection)
            if listener.active then
                listener.active = false
                table.insert(log, `disconnect:{name}`)
            end
        end
        return connection
    end

    function signal:Fire(value: any?)
        for _, listener in listeners do
            if listener.active then
                listener.callback(value)
            end
        end
    end

    return signal
end

local function newCharacter(name: string, y: number, log: { string }): any
    local humanoid = {
        Health = 100,
        Died = newSignal(log, `{name}.Died`),
    }
    return {
        Name = name,
        y = y,
        humanoid = humanoid,
    }
end

local function newPlayer(name: string, withCharacter: boolean?): any
    local log = {}
    local player: any = {
        Name = name,
        Character = nil,
        CharacterAdded = newSignal(log, `{name}.CharacterAdded`),
        attributes = {},
        log = log,
    }
    if withCharacter ~= false then
        player.Character = newCharacter(`{name}.Character1`, 5, log)
    end
    return player
end

local function newPlayers(existing: { any }, log: { string })
    local players = {
        CharacterAutoLoads = true,
        PlayerAdded = newSignal(log, "PlayerAdded"),
        PlayerRemoving = newSignal(log, "PlayerRemoving"),
    }
    function players:GetPlayers()
        table.insert(log, "enumerate")
        return table.clone(existing)
    end
    return players
end

type Context = {
    handle: any?,
    state: any?,
    rejectNext: boolean,
}

type EventRecord = {
    player: any,
    handle: any,
    event: any,
}

local function newRoundController()
    local contexts: { [any]: Context } = {}
    local events: { EventRecord } = {}
    local controller = {}

    function controller.addPlayer(player: any)
        local active, accepted = RoundLifecycle.transition(RoundLifecycle.new(), {
            type = "START",
        })
        assert(accepted, "fake round must start")
        contexts[player] = {
            handle = {},
            state = active,
            rejectNext = false,
        }
    end

    function controller.getSessionHandle(player: any): any?
        local context = contexts[player]
        return if context == nil then nil else context.handle
    end

    function controller.getState(player: any): any?
        local context = contexts[player]
        return if context == nil then nil else context.state
    end

    function controller.applyServerEvent(player: any, handle: any, event: any): (boolean, any)
        table.insert(events, {
            player = player,
            handle = handle,
            event = event,
        })
        local context = contexts[player]
        if context == nil then
            return false, "UNKNOWN_PLAYER"
        end
        if context.handle ~= handle then
            return false, "SESSION_MISMATCH"
        end
        if context.rejectNext then
            context.rejectNext = false
            return false, "GENERATION_MISMATCH"
        end
        local nextState, accepted, rejection = RoundLifecycle.transition(context.state, event)
        if accepted then
            context.state = nextState
            if event.type == "START" and controller.startGenerationOverride ~= nil then
                context.state = table.freeze({
                    phase = "ACTIVE",
                    generation = controller.startGenerationOverride,
                    result = nil,
                    failureReason = nil,
                })
            end
        end
        return accepted, rejection
    end

    controller.contexts = contexts
    controller.events = events
    controller.startGenerationOverride = nil
    return controller
end

local function newObjectiveController(existing: { any })
    local slots = {}
    local calls = {}
    local controller = {
        failFor = nil,
    }
    for index, player in existing do
        slots[player] = index
    end
    function controller.addPlayer(player: any, slot: number?)
        slots[player] = slot or 1
    end
    function controller.repositionObjective(player: any): (any?, any)
        table.insert(calls, player)
        if controller.failFor == player or slots[player] == nil then
            return nil, "UNKNOWN_PLAYER"
        end
        local nextSlot = (slots[player] % 8) + 1
        slots[player] = nextSlot
        return {
            slotId = nextSlot,
        }, nil
    end
    controller.slots = slots
    controller.calls = calls
    return controller
end

type LoadRequest = {
    player: any,
    complete: (boolean, string?) -> (),
}

local function newFixture(existing: { any })
    local log = {}
    local players = newPlayers(existing, log)
    local heartbeat = newSignal(log, "Heartbeat")
    local clock = {
        value = 100,
    }
    local round = newRoundController()
    local objective = newObjectiveController(existing)
    local loads: { LoadRequest } = {}
    local writes = {}
    local failures = {}

    for _, player in existing do
        round.addPlayer(player)
    end

    local controller = FailureReplayAdapter.start(round, objective, {
        players = players,
        heartbeat = heartbeat,
        now = function()
            return clock.value
        end,
        findHumanoid = function(character)
            return character.humanoid
        end,
        getCharacterY = function(character)
            if character.failY then
                error("injected character-height failure")
            end
            return character.y
        end,
        loadCharacterAsync = function(player, complete)
            table.insert(loads, {
                player = player,
                complete = complete,
            })
        end,
        setAttribute = function(player, name, value)
            player.attributes[name] = value
            table.insert(writes, {
                player = player,
                name = name,
                value = value,
            })
        end,
        reportFailure = function(message)
            table.insert(failures, message)
        end,
    })

    local fixture = {
        controller = controller,
        players = players,
        heartbeat = heartbeat,
        clock = clock,
        round = round,
        objective = objective,
        loads = loads,
        writes = writes,
        failures = failures,
        log = log,
    }

    function fixture.tick(seconds: number?)
        clock.value += seconds or 0
        heartbeat:Fire(nil)
    end

    function fixture.addPlayer(player: any, slot: number?)
        round.addPlayer(player)
        objective.addPlayer(player, slot)
        players.PlayerAdded:Fire(player)
    end

    function fixture.completeLatestLoad(player: any, succeeded: boolean)
        local request = loads[#loads]
        assert(request ~= nil and request.player == player, "expected latest load for player")
        if succeeded then
            local character = newCharacter(`{player.Name}.Replacement`, 5, player.log)
            player.Character = character
            player.CharacterAdded:Fire(character)
        end
        request.complete(succeeded, if succeeded then nil else "load failed")
    end

    return fixture
end

local function countEvents(fixture: any, player: any, eventType: string, reason: string?): number
    local count = 0
    for _, record in fixture.round.events do
        if
            record.player == player
            and record.event.type == eventType
            and (reason == nil or record.event.reason == reason)
        then
            count += 1
        end
    end
    return count
end

local function countPlayerEvents(fixture: any, player: any): number
    local count = 0
    for _, record in fixture.round.events do
        if record.player == player then
            count += 1
        end
    end
    return count
end

local function succeed(fixture: any, player: any)
    local context = fixture.round.contexts[player]
    local accepted = fixture.round.applyServerEvent(player, context.handle, {
        type = "SUCCEED",
        generation = context.state.generation,
    })
    assert(accepted, "fake success must be accepted")
end

local function fail(fixture: any, player: any, reason: string)
    local context = fixture.round.contexts[player]
    local accepted = fixture.round.applyServerEvent(player, context.handle, {
        type = "FAIL",
        generation = context.state.generation,
        reason = reason,
    })
    assert(accepted, "fake failure must be accepted")
end

local function finishReplay(fixture: any, player: any)
    fixture.tick(0)
    fixture.tick(2)
    fixture.completeLatestLoad(player, true)
    fixture.tick(1)
end

return {
    suite = "Failure replay adapter",
    cases = {
        {
            name = "owns autoload and connects every global source before enumeration",
            run = function()
                local player = newPlayer("Startup")
                local fixture = newFixture({ player })
                assert(not fixture.players.CharacterAutoLoads, "adapter must disable autoload")
                assert(fixture.log[1] == "connect:PlayerAdded", "PlayerAdded must connect first")
                assert(
                    fixture.log[2] == "connect:PlayerRemoving",
                    "PlayerRemoving must connect second"
                )
                assert(fixture.log[3] == "connect:Heartbeat", "heartbeat must connect third")
                assert(fixture.log[4] == "enumerate", "enumeration must follow connections")
                assert(
                    fixture.round.contexts[player].state.phase == "ACTIVE",
                    "startup must not alter provider state"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "arms one stable twenty-second active deadline",
            run = function()
                local player = newPlayer("Deadline")
                local fixture = newFixture({ player })
                fixture.tick(0)
                assert(player.attributes.GrayboxPhaseEndsAt == 120, "deadline must be now plus 20")
                local writes = #fixture.writes
                fixture.tick(5)
                fixture.tick(0)
                assert(
                    player.attributes.GrayboxPhaseEndsAt == 120,
                    "heartbeat must not extend timer"
                )
                assert(#fixture.writes == writes, "stable deadline must not republish")
                fixture.controller.stop()
            end,
        },
        {
            name = "requests one missing initial Character and rejects stale completion",
            run = function()
                local player = newPlayer("InitialLoad", false)
                local fixture = newFixture({ player })
                fixture.tick(0)
                fixture.tick(1)
                assert(#fixture.loads == 1, "missing initial Character must load once")
                fixture.players.PlayerRemoving:Fire(player)
                fixture.loads[1].complete(false, "late")
                assert(#fixture.failures == 0, "removed load completion must be inert")
                fixture.controller.stop()
            end,
        },
        {
            name = "submits timeout exactly at the active deadline once",
            run = function()
                local player = newPlayer("Timeout")
                local fixture = newFixture({ player })
                fixture.tick(0)
                fixture.tick(19)
                assert(countEvents(fixture, player, "FAIL", "TIMEOUT") == 0, "must not fail early")
                fixture.tick(1)
                assert(countEvents(fixture, player, "FAIL", "TIMEOUT") == 1, "timeout must submit")
                fixture.tick(5)
                assert(countEvents(fixture, player, "FAIL", "TIMEOUT") == 1, "timeout must dedupe")
                fixture.controller.stop()
            end,
        },
        {
            name = "accepts only the current Humanoid death once",
            run = function()
                local player = newPlayer("Death")
                local oldCharacter = player.Character
                local fixture = newFixture({ player })
                fixture.tick(0)
                local replacement = newCharacter("Death.Character2", 5, player.log)
                player.Character = replacement
                player.CharacterAdded:Fire(replacement)
                oldCharacter.humanoid.Died:Fire(nil)
                assert(
                    countEvents(fixture, player, "FAIL", "DEATH") == 0,
                    "old death must be inert"
                )
                replacement.humanoid.Died:Fire(nil)
                replacement.humanoid.Died:Fire(nil)
                assert(
                    countEvents(fixture, player, "FAIL", "DEATH") == 1,
                    "current death must dedupe"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "submits void only for the current Character below the boundary",
            run = function()
                local player = newPlayer("Void")
                local fixture = newFixture({ player })
                fixture.tick(0)
                player.Character.y = -20
                fixture.tick(0)
                assert(countEvents(fixture, player, "FAIL", "VOID") == 0, "boundary is not below")
                player.Character.y = -20.1
                fixture.tick(0)
                fixture.tick(0)
                assert(countEvents(fixture, player, "FAIL", "VOID") == 1, "void must dedupe")
                fixture.controller.stop()
            end,
        },
        {
            name = "prioritizes void over simultaneous timeout and preserves accepted success",
            run = function()
                local player = newPlayer("Priority")
                local fixture = newFixture({ player })
                fixture.tick(0)
                player.Character.y = -21
                fixture.tick(20)
                assert(countEvents(fixture, player, "FAIL", "VOID") == 1, "void must win heartbeat")
                assert(
                    countEvents(fixture, player, "FAIL", "TIMEOUT") == 0,
                    "timeout must not follow void"
                )
                fixture.controller.stop()

                local successPlayer = newPlayer("SuccessFirst")
                local successFixture = newFixture({ successPlayer })
                successFixture.tick(0)
                succeed(successFixture, successPlayer)
                successPlayer.Character.y = -30
                successFixture.tick(20)
                assert(
                    countEvents(successFixture, successPlayer, "FAIL", nil) == 0,
                    "accepted success must remain immutable"
                )
                successFixture.controller.stop()
            end,
        },
        {
            name = "rejects missing malformed inactive and stale terminal context without leakage",
            run = function()
                local first = newPlayer("InvalidFirst")
                local second = newPlayer("InvalidSecond")
                local fixture = newFixture({ first, second })
                fixture.round.contexts[first].handle = nil
                fixture.tick(0)
                first.Character.y = -30
                fixture.tick(0)
                assert(countEvents(fixture, first, "FAIL", nil) == 0, "missing handle must reject")
                assert(
                    fixture.round.contexts[second].state.phase == "ACTIVE",
                    "invalid first context must not affect second"
                )

                fixture.round.contexts[first].handle = {}
                fixture.round.contexts[first].state = {
                    phase = "BROKEN",
                    generation = "one",
                }
                fixture.tick(0)
                assert(countEvents(fixture, first, "FAIL", nil) == 0, "malformed state must reject")
                fixture.controller.stop()

                local rejected = newPlayer("RejectedRace")
                local rejectedFixture = newFixture({ rejected })
                rejectedFixture.tick(0)
                rejectedFixture.round.contexts[rejected].rejectNext = true
                rejected.Character.y = -30
                rejectedFixture.tick(0)
                rejected.Character.y = 5
                rejectedFixture.tick(20)
                assert(
                    countEvents(rejectedFixture, rejected, "FAIL", nil) == 1,
                    "rejected terminal attempt must not retry for the same generation"
                )
                assert(
                    rejectedFixture.round.contexts[rejected].state.phase == "ACTIVE",
                    "rejected race must preserve lifecycle state"
                )
                rejectedFixture.controller.stop()
            end,
        },
        {
            name = "schedules one result deadline for accepted success and failure",
            run = function()
                local successPlayer = newPlayer("ResultSuccess")
                local failurePlayer = newPlayer("ResultFailure")
                local fixture = newFixture({ successPlayer, failurePlayer })
                succeed(fixture, successPlayer)
                fail(fixture, failurePlayer, "DEATH")
                fixture.tick(0)
                assert(
                    successPlayer.attributes.GrayboxPhaseEndsAt == 102,
                    "success result deadline must be two seconds"
                )
                assert(
                    failurePlayer.attributes.GrayboxPhaseEndsAt == 102,
                    "failure result deadline must be two seconds"
                )
                fixture.tick(1)
                assert(
                    fixture.round.contexts[successPlayer].state.result == "SUCCESS",
                    "success result must remain immutable"
                )
                assert(
                    fixture.round.contexts[failurePlayer].state.failureReason == "DEATH",
                    "failure reason must remain immutable"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "begins reset once at the result deadline",
            run = function()
                local player = newPlayer("BeginReset")
                local fixture = newFixture({ player })
                succeed(fixture, player)
                fixture.tick(0)
                fixture.tick(1.9)
                assert(countEvents(fixture, player, "BEGIN_RESET", nil) == 0, "must wait")
                fixture.tick(0.1)
                fixture.tick(0)
                assert(
                    countEvents(fixture, player, "BEGIN_RESET", nil) == 1,
                    "reset must begin once"
                )
                assert(
                    fixture.round.contexts[player].state.phase == "RESETTING",
                    "accepted begin must reset"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "accepted reset moves objective loads Character and disconnects old death",
            run = function()
                local player = newPlayer("ResetWork")
                local oldCharacter = player.Character
                local fixture = newFixture({ player })
                succeed(fixture, player)
                fixture.tick(0)
                fixture.tick(2)
                assert(#fixture.objective.calls == 1, "objective must reposition once")
                assert(#fixture.loads == 1, "reset must request one Character load")
                assert(
                    player.attributes.GrayboxPhaseEndsAt == 103,
                    "reset deadline must be one second"
                )
                oldCharacter.humanoid.Died:Fire(nil)
                assert(
                    countEvents(fixture, player, "FAIL", "DEATH") == 0,
                    "old death must be inert"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "requires reset deadline replacement Character and successful reset work",
            run = function()
                local player = newPlayer("ResetReady")
                local fixture = newFixture({ player })
                succeed(fixture, player)
                fixture.tick(0)
                fixture.tick(2)
                fixture.tick(1)
                assert(countEvents(fixture, player, "FINISH_RESET", nil) == 0, "Character required")
                fixture.completeLatestLoad(player, true)
                fixture.tick(0)
                assert(
                    countEvents(fixture, player, "FINISH_RESET", nil) == 1,
                    "ready reset finishes"
                )
                fixture.controller.stop()

                local failedPlayer = newPlayer("ResetFailure")
                local failedFixture = newFixture({ failedPlayer })
                failedFixture.objective.failFor = failedPlayer
                succeed(failedFixture, failedPlayer)
                failedFixture.tick(0)
                failedFixture.tick(2)
                failedFixture.tick(5)
                assert(#failedFixture.loads == 0, "failed reposition must not load Character")
                assert(
                    countEvents(failedFixture, failedPlayer, "FINISH_RESET", nil) == 0,
                    "failed reset must not finish"
                )
                assert(#failedFixture.failures == 1, "failed reset must report")
                failedFixture.controller.stop()

                local loadFailurePlayer = newPlayer("ResetLoadFailure")
                local loadFailureFixture = newFixture({ loadFailurePlayer })
                succeed(loadFailureFixture, loadFailurePlayer)
                loadFailureFixture.tick(0)
                loadFailureFixture.tick(2)
                loadFailureFixture.completeLatestLoad(loadFailurePlayer, false)
                loadFailureFixture.tick(5)
                assert(
                    countEvents(loadFailureFixture, loadFailurePlayer, "FINISH_RESET", nil) == 0,
                    "failed Character load must not finish reset"
                )
                assert(#loadFailureFixture.failures == 1, "load failure must report")
                loadFailureFixture.controller.stop()
            end,
        },
        {
            name = "finishes and starts exactly one clean greater generation",
            run = function()
                local player = newPlayer("Replay")
                local fixture = newFixture({ player })
                local originalGeneration = fixture.round.contexts[player].state.generation
                succeed(fixture, player)
                finishReplay(fixture, player)
                local state = fixture.round.contexts[player].state
                assert(state.phase == "ACTIVE", "replay must become active")
                assert(state.generation == originalGeneration + 1, "generation must increase once")
                assert(state.result == nil and state.failureReason == nil, "replay must be clean")
                assert(countEvents(fixture, player, "FINISH_RESET", nil) == 1, "finish once")
                assert(countEvents(fixture, player, "START", nil) == 1, "start once")
                assert(player.attributes.GrayboxPhaseEndsAt == 123, "new active deadline required")
                fixture.tick(0)
                assert(
                    countEvents(fixture, player, "START", nil) == 1,
                    "heartbeat must not restart"
                )
                fixture.controller.stop()

                local authoritativePlayer = newPlayer("AuthoritativeGeneration")
                local authoritativeFixture = newFixture({ authoritativePlayer })
                authoritativeFixture.round.startGenerationOverride = 7
                succeed(authoritativeFixture, authoritativePlayer)
                finishReplay(authoritativeFixture, authoritativePlayer)
                assert(
                    authoritativeFixture.round.contexts[authoritativePlayer].state.generation == 7,
                    "adapter must retain the authority's post-START generation"
                )
                local authoritativeDeadline = authoritativePlayer.attributes.GrayboxPhaseEndsAt
                authoritativeFixture.tick(0)
                assert(
                    authoritativePlayer.attributes.GrayboxPhaseEndsAt == authoritativeDeadline,
                    "authoritative readback must not re-arm the deadline"
                )
                authoritativeFixture.controller.stop()
            end,
        },
        {
            name = "keeps consecutive success and failure replays clean",
            run = function()
                local player = newPlayer("Consecutive")
                local fixture = newFixture({ player })
                succeed(fixture, player)
                finishReplay(fixture, player)
                local afterSuccess = fixture.round.contexts[player].state.generation
                player.Character.y = -21
                fixture.tick(0)
                fixture.tick(0)
                assert(
                    fixture.round.contexts[player].state.failureReason == "VOID",
                    "second round must accept failure"
                )
                finishReplay(fixture, player)
                local state = fixture.round.contexts[player].state
                assert(state.generation == afterSuccess + 1, "second replay must increment once")
                assert(state.result == nil and state.failureReason == nil, "nothing may carry")
                assert(#fixture.objective.calls == 2, "each reset must reposition once")
                fixture.controller.stop()

                local reversePlayer = newPlayer("ConsecutiveReverse")
                local reverseFixture = newFixture({ reversePlayer })
                fail(reverseFixture, reversePlayer, "DEATH")
                finishReplay(reverseFixture, reversePlayer)
                local afterFailure = reverseFixture.round.contexts[reversePlayer].state.generation
                succeed(reverseFixture, reversePlayer)
                finishReplay(reverseFixture, reversePlayer)
                local reverseState = reverseFixture.round.contexts[reversePlayer].state
                assert(
                    reverseState.generation == afterFailure + 1,
                    "reverse-order replay must increment once"
                )
                assert(
                    reverseState.result == nil and reverseState.failureReason == nil,
                    "reverse-order replay must also be clean"
                )
                reverseFixture.controller.stop()
            end,
        },
        {
            name = "character replacement cannot duplicate terminal or reset work",
            run = function()
                local player = newPlayer("Replacement")
                local oldCharacter = player.Character
                local fixture = newFixture({ player })
                fixture.tick(0)
                local replacement = newCharacter("Replacement.Character2", 5, player.log)
                player.Character = replacement
                player.CharacterAdded:Fire(replacement)
                player.CharacterAdded:Fire(replacement)
                oldCharacter.humanoid.Died:Fire(nil)
                replacement.humanoid.Died:Fire(nil)
                replacement.humanoid.Died:Fire(nil)
                assert(countEvents(fixture, player, "FAIL", "DEATH") == 1, "death must remain once")
                fixture.tick(0)
                fixture.tick(2)
                assert(#fixture.objective.calls == 1 and #fixture.loads == 1, "reset work once")
                fixture.controller.stop()
            end,
        },
        {
            name = "keeps two player clocks outcomes objectives and replays isolated",
            run = function()
                local first = newPlayer("IsolatedFirst")
                local second = newPlayer("IsolatedSecond")
                local fixture = newFixture({ first, second })
                fixture.tick(0)
                first.Character.y = -21
                fixture.tick(0)
                assert(
                    fixture.round.contexts[first].state.failureReason == "VOID",
                    "first must fail"
                )
                assert(
                    fixture.round.contexts[second].state.phase == "ACTIVE",
                    "second stays active"
                )
                fixture.tick(0)
                fixture.tick(2)
                assert(fixture.objective.calls[1] == first, "only first objective must move")
                assert(#fixture.loads == 1 and fixture.loads[1].player == first, "only first loads")
                assert(second.attributes.GrayboxPhaseEndsAt == 120, "second timer must remain")
                fixture.controller.stop()

                local faulty = newPlayer("FaultyUpdate")
                local healthy = newPlayer("HealthyUpdate")
                local isolatedFixture = newFixture({ faulty, healthy })
                isolatedFixture.tick(0)
                faulty.Character.failY = true
                healthy.Character.y = -21
                isolatedFixture.tick(0)
                assert(#isolatedFixture.failures == 1, "faulty update must be reported")
                assert(
                    isolatedFixture.round.contexts[healthy].state.failureReason == "VOID",
                    "faulty player must not skip a healthy player's tick"
                )
                isolatedFixture.controller.stop()
            end,
        },
        {
            name = "initializes a late joiner independently once",
            run = function()
                local first = newPlayer("LateFirst")
                local fixture = newFixture({ first })
                fixture.tick(0)
                local firstDeadline = first.attributes.GrayboxPhaseEndsAt
                local late = newPlayer("LateSecond", false)
                fixture.addPlayer(late, 2)
                -- Deliberately repeat the signal; the exact-once load assertion below
                -- proves late-join initialization is idempotent.
                fixture.players.PlayerAdded:Fire(late)
                fixture.tick(3)
                assert(late.attributes.GrayboxPhaseEndsAt == 123, "late timer must start")
                assert(#fixture.loads == 1 and fixture.loads[1].player == late, "late load once")
                assert(
                    first.attributes.GrayboxPhaseEndsAt == firstDeadline,
                    "first timer unchanged"
                )
                assert(
                    fixture.round.contexts[first].state.phase == "ACTIVE",
                    "first state unchanged"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "removes active result and resetting players without retained work",
            run = function()
                for _, phase in { "ACTIVE", "RESULT", "RESETTING" } do
                    local player = newPlayer(`Remove{phase}`)
                    local other = newPlayer(`Other{phase}`)
                    local fixture = newFixture({ player, other })
                    fixture.tick(0)
                    if phase ~= "ACTIVE" then
                        succeed(fixture, player)
                        fixture.tick(0)
                    end
                    if phase == "RESETTING" then
                        fixture.tick(2)
                    end
                    fixture.players.PlayerRemoving:Fire(player)
                    local eventsBefore = countPlayerEvents(fixture, player)
                    fixture.tick(5)
                    player.Character.humanoid.Died:Fire(nil)
                    if #fixture.loads > 0 then
                        fixture.loads[#fixture.loads].complete(true, nil)
                    end
                    assert(
                        countPlayerEvents(fixture, player) == eventsBefore,
                        "removed work must be inert"
                    )
                    assert(
                        player.attributes.GrayboxPhaseEndsAt == nil,
                        "removed timing attribute must clear"
                    )
                    assert(
                        fixture.round.contexts[other].state.phase == "ACTIVE",
                        "other player must remain active"
                    )
                    fixture.controller.stop()
                end
            end,
        },
        {
            name = "stops idempotently restores autoload and makes callbacks inert",
            run = function()
                local player = newPlayer("Stop")
                local fixture = newFixture({ player })
                fixture.tick(0)
                local eventsBefore = #fixture.round.events
                fixture.controller.stop()
                fixture.controller.stop()
                assert(fixture.players.CharacterAutoLoads, "stop must restore autoload")
                assert(player.attributes.GrayboxPhaseEndsAt == nil, "stop must clear timing")
                fixture.tick(30)
                player.Character.humanoid.Died:Fire(nil)
                fixture.players.PlayerAdded:Fire(newPlayer("AfterStop"))
                assert(#fixture.round.events == eventsBefore, "stopped callbacks must be inert")
            end,
        },
        {
            name = "exposes only stop and creates no client remote or persistence surface",
            run = function()
                local fixture = newFixture({})
                local keys = {}
                local count = 0
                for key in fixture.controller do
                    keys[key] = true
                    count += 1
                end
                assert(keys.stop and count == 1, "controller must expose only stop")
                assert(
                    (fixture.controller :: any).RemoteEvent == nil
                        and (fixture.controller :: any).RemoteFunction == nil
                        and (fixture.controller :: any).save == nil
                        and (fixture.controller :: any).showUi == nil,
                    "adapter must add no remote persistence or UI surface"
                )
                fixture.controller.stop()
            end,
        },
    },
}
