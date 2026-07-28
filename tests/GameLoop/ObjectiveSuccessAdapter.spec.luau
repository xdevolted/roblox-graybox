--!strict

local ObjectiveSuccessAdapter = require("../../src/server/GameLoop/ObjectiveSuccessAdapter")

type Callback = (value: any) -> ()

local function newSignal(log: { string }, name: string)
    local listeners = {}
    local signal: any = {
        listeners = listeners,
        connectCount = 0,
        disconnectCount = 0,
    }

    function signal.Connect(_signal, callback: Callback)
        signal.connectCount += 1
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
                signal.disconnectCount += 1
                table.insert(log, `disconnect:{name}`)
            end
        end
        return connection
    end

    function signal.Fire(_signal, value: any)
        for _, listener in listeners do
            if listener.active then
                listener.callback(value)
            end
        end
    end

    function signal.FireRetained(_signal, index: number, value: any)
        listeners[index].callback(value)
    end

    return signal
end

local function newPlayers(existing: { any }, log: { string }, onEnumerate: (() -> ())?)
    local players: any = {
        PlayerAdded = newSignal(log, "PlayerAdded"),
        PlayerRemoving = newSignal(log, "PlayerRemoving"),
    }

    function players.GetPlayers(_players)
        table.insert(log, "enumerate")
        if onEnumerate ~= nil then
            onEnumerate()
        end
        return table.clone(existing)
    end

    return players
end

local function newCharacter(health: number?): any
    return {
        humanoid = if health == nil then nil else { Health = health },
    }
end

local function newPlayer(name: string, log: { string }): any
    return {
        Name = name,
        Character = newCharacter(100),
        CharacterAdded = newSignal(log, `CharacterAdded:{name}`),
        attributes = {},
    }
end

local function newPart(character: any?, basePart: boolean?): any
    return {
        character = character,
        basePart = if basePart == nil then true else basePart,
    }
end

local function newObjective(name: string, log: { string }): any
    return {
        Name = name,
        Touched = newSignal(log, `Touched:{name}`),
        attributes = {
            owner = name,
        },
        position = name,
    }
end

local function activeState(generation: number): any
    return {
        phase = "ACTIVE",
        generation = generation,
        result = nil,
        failureReason = nil,
    }
end

local function newRoundController()
    local controller: any = {
        handles = {},
        states = {},
        submissions = {},
        handleReads = 0,
        stateReads = 0,
        publications = 0,
        accept = true,
        beforeApply = nil,
    }

    function controller.getSessionHandle(player: any)
        controller.handleReads += 1
        return controller.handles[player]
    end

    function controller.getState(player: any)
        controller.stateReads += 1
        return controller.states[player]
    end

    function controller.applyServerEvent(player: any, handle: any, event: any)
        table.insert(controller.submissions, {
            player = player,
            handle = handle,
            event = event,
        })

        if controller.beforeApply ~= nil then
            controller.beforeApply(player, handle, event)
        end
        if not controller.accept then
            return false, "REJECTED"
        end

        local state = controller.states[player]
        if
            controller.handles[player] ~= handle
            or state == nil
            or state.phase ~= "ACTIVE"
            or state.generation ~= event.generation
        then
            return false, "STALE_CONTEXT"
        end

        controller.states[player] = {
            phase = "RESULT",
            generation = state.generation,
            result = "SUCCESS",
            failureReason = nil,
        }
        controller.publications += 1
        return true, nil
    end

    return controller
end

local function addPlayerContext(fixture: any, player: any, objective: any?)
    fixture.round.handles[player] = {}
    fixture.round.states[player] = activeState(1)
    fixture.objectives[player] = if objective == nil
        then newObjective(player.Name, fixture.log)
        else objective
end

local function newFixture(existing: { any }, configure: ((fixture: any) -> ())?)
    local log = {}
    local fixture: any = {
        log = log,
        round = newRoundController(),
        objectives = {},
    }

    for _, player in existing do
        addPlayerContext(fixture, player, nil)
    end

    if configure ~= nil then
        configure(fixture)
    end

    fixture.players = newPlayers(existing, log, nil)
    fixture.objectiveController = {
        getObjective = function(player: any)
            return fixture.objectives[player]
        end,
    }
    fixture.controller = ObjectiveSuccessAdapter.start(fixture.round, fixture.objectiveController, {
        players = fixture.players,
        isBasePart = function(value)
            return type(value) == "table" and value.basePart == true
        end,
        isDescendantOf = function(part, character)
            return part.character == character
        end,
        findHumanoid = function(character)
            return character.humanoid
        end,
    })
    return fixture
end

local function submissionCount(fixture: any): number
    return #fixture.round.submissions
end

return {
    suite = "Objective success adapter",
    cases = {
        {
            name = "connects player signals before enumeration and observes each source once",
            run = function()
                local log = {}
                local player = newPlayer("owner", log)
                local fixture = newFixture({ player }, nil)
                assert(fixture.log[1] == "connect:PlayerAdded", "PlayerAdded must connect first")
                assert(
                    fixture.log[2] == "connect:PlayerRemoving",
                    "PlayerRemoving must connect second"
                )
                assert(fixture.log[3] == "enumerate", "enumeration must follow global signals")
                assert(player.CharacterAdded.connectCount == 1, "Character retry must connect once")
                assert(
                    fixture.objectives[player].Touched.connectCount == 1,
                    "objective touch must connect once"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "submits one matching-generation success for valid owner contact",
            run = function()
                local log = {}
                local player = newPlayer("owner", log)
                local fixture = newFixture({ player }, nil)
                local handle = fixture.round.handles[player]
                fixture.objectives[player].Touched:Fire(newPart(player.Character))
                assert(submissionCount(fixture) == 1, "valid owner contact must submit once")
                local submission = fixture.round.submissions[1]
                assert(submission.player == player, "submission must address the owner")
                assert(submission.handle == handle, "submission must use the captured handle")
                assert(
                    submission.event.type == "SUCCEED" and submission.event.generation == 1,
                    "submission must contain matching-generation SUCCEED"
                )
                assert(
                    fixture.round.handleReads == 1 and fixture.round.stateReads == 1,
                    "current context must be read at touch time"
                )
                assert(
                    fixture.round.states[player].phase == "RESULT"
                        and fixture.round.states[player].result == "SUCCESS",
                    "trusted controller must publish immediate success"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "uses only the trusted controller without mutating attributes or objective",
            run = function()
                local log = {}
                local player = newPlayer("owner", log)
                local fixture = newFixture({ player }, nil)
                local objective = fixture.objectives[player]
                local attributes = objective.attributes
                local position = objective.position
                fixture.objectives[player].Touched:Fire(newPart(player.Character))
                assert(submissionCount(fixture) == 1, "trusted controller must receive success")
                assert(
                    player.attributes.GrayboxRoundResult == nil,
                    "adapter must write no attributes"
                )
                assert(
                    objective.attributes == attributes,
                    "objective metadata identity must remain"
                )
                assert(objective.position == position, "objective position must remain unchanged")
                fixture.controller.stop()
            end,
        },
        {
            name = "rejects world unrelated and foreign-character contacts",
            run = function()
                local log = {}
                local owner = newPlayer("owner", log)
                local foreign = newPlayer("foreign", log)
                local fixture = newFixture({ owner, foreign }, nil)
                local objective = fixture.objectives[owner]
                objective.Touched:Fire(newPart(nil))
                objective.Touched:Fire(newPart(owner.Character, false))
                objective.Touched:Fire(newPart(foreign.Character))
                assert(submissionCount(fixture) == 0, "non-owner contacts must not submit")
                assert(fixture.round.states[owner].phase == "ACTIVE", "owner must remain active")
                assert(
                    fixture.round.states[foreign].phase == "ACTIVE",
                    "foreign player must remain active"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "rejects missing dead and stale characters but accepts the new living character",
            run = function()
                local log = {}
                local player = newPlayer("owner", log)
                local fixture = newFixture({ player }, nil)
                local objective = fixture.objectives[player]

                player.Character = newCharacter(nil)
                objective.Touched:Fire(newPart(player.Character))
                player.Character = newCharacter(0)
                objective.Touched:Fire(newPart(player.Character))

                local staleCharacter = newCharacter(100)
                player.Character = newCharacter(100)
                objective.Touched:Fire(newPart(staleCharacter))
                assert(submissionCount(fixture) == 0, "invalid characters must not submit")

                objective.Touched:Fire(newPart(player.Character))
                assert(submissionCount(fixture) == 1, "new current living character must qualify")
                fixture.controller.stop()
            end,
        },
        {
            name = "rejects missing round context inactive state and replaced objectives",
            run = function()
                local log = {}
                local player = newPlayer("owner", log)
                local fixture = newFixture({ player }, function(context)
                    context.objectives[player] = nil
                end)
                assert(
                    player.CharacterAdded.connectCount == 1,
                    "missing objective keeps retry seam"
                )

                local oldObjective = newObjective("old", fixture.log)
                fixture.objectives[player] = oldObjective
                player.CharacterAdded:Fire(player.Character)
                assert(
                    oldObjective.Touched.connectCount == 1,
                    "retry must bind available objective"
                )

                local handle = fixture.round.handles[player]
                fixture.round.handles[player] = nil
                oldObjective.Touched:Fire(newPart(player.Character))
                fixture.round.handles[player] = handle
                fixture.round.states[player] = nil
                oldObjective.Touched:Fire(newPart(player.Character))
                fixture.round.states[player] = {
                    phase = "RESULT",
                    generation = 1,
                    result = "SUCCESS",
                    failureReason = nil,
                }
                oldObjective.Touched:Fire(newPart(player.Character))
                assert(submissionCount(fixture) == 0, "missing or inactive context must reject")

                fixture.round.states[player] = activeState(1)
                local replacement = newObjective("replacement", fixture.log)
                fixture.objectives[player] = replacement
                oldObjective.Touched:Fire(newPart(player.Character))
                player.CharacterAdded:Fire(player.Character)
                oldObjective.Touched:FireRetained(1, newPart(player.Character))
                assert(submissionCount(fixture) == 0, "retained old objective must reject")
                replacement.Touched:Fire(newPart(player.Character))
                assert(submissionCount(fixture) == 1, "current replacement may qualify after retry")
                fixture.controller.stop()
            end,
        },
        {
            name = "deduplicates every contact for one handle and generation even after rejection",
            run = function()
                local log = {}
                local player = newPlayer("owner", log)
                local fixture = newFixture({ player }, nil)
                fixture.round.accept = false
                local objective = fixture.objectives[player]
                objective.Touched:Fire(newPart(player.Character))
                objective.Touched:Fire(newPart(player.Character))
                objective.Touched:Fire(newPart(player.Character))
                assert(submissionCount(fixture) == 1, "one context may be attempted only once")
                assert(fixture.round.publications == 0, "rejected submission must not publish")
                fixture.controller.stop()
            end,
        },
        {
            name = "does not retry a stale-context race or mutate another player",
            run = function()
                local log = {}
                local first = newPlayer("first", log)
                local second = newPlayer("second", log)
                local fixture = newFixture({ first, second }, nil)
                local secondState = fixture.round.states[second]
                fixture.round.accept = false
                fixture.objectives[first].Touched:Fire(newPart(first.Character))
                fixture.objectives[first].Touched:Fire(newPart(first.Character))
                assert(submissionCount(fixture) == 1, "stale race must not retry")
                assert(fixture.round.publications == 0, "stale race must not publish")
                assert(fixture.round.states[second] == secondState, "other player must not change")
                fixture.controller.stop()
            end,
        },
        {
            name = "allows new sessions and generations while rejecting an old objective callback",
            run = function()
                local log = {}
                local player = newPlayer("owner", log)
                local fixture = newFixture({ player }, nil)
                local oldObjective = fixture.objectives[player]
                oldObjective.Touched:Fire(newPart(player.Character))
                assert(submissionCount(fixture) == 1, "first session must qualify")

                local replacement = newObjective("replacement", fixture.log)
                fixture.objectives[player] = replacement
                player.CharacterAdded:Fire(player.Character)
                fixture.round.handles[player] = {}
                fixture.round.states[player] = activeState(1)
                oldObjective.Touched:FireRetained(1, newPart(player.Character))
                assert(submissionCount(fixture) == 1, "old objective must not target new session")
                replacement.Touched:Fire(newPart(player.Character))
                assert(submissionCount(fixture) == 2, "new session must be independently eligible")

                fixture.round.states[player] = activeState(2)
                replacement.Touched:Fire(newPart(player.Character))
                assert(
                    submissionCount(fixture) == 3,
                    "later generation must be independently eligible"
                )
                assert(
                    fixture.round.submissions[3].event.generation == 2,
                    "later attempt must capture new generation"
                )
                fixture.controller.stop()
            end,
        },
        {
            name = "isolates two players and accepts only each owner's objective contact",
            run = function()
                local log = {}
                local first = newPlayer("first", log)
                local second = newPlayer("second", log)
                local fixture = newFixture({ first, second }, nil)
                fixture.objectives[first].Touched:Fire(newPart(second.Character))
                fixture.objectives[second].Touched:Fire(newPart(first.Character))
                assert(submissionCount(fixture) == 0, "cross-objective contacts must reject")

                fixture.objectives[first].Touched:Fire(newPart(first.Character))
                assert(fixture.round.states[first].result == "SUCCESS", "first owner must succeed")
                assert(fixture.round.states[second].phase == "ACTIVE", "second must remain active")
                fixture.objectives[second].Touched:Fire(newPart(second.Character))
                assert(
                    fixture.round.states[second].result == "SUCCESS",
                    "second owner must succeed"
                )
                assert(submissionCount(fixture) == 2, "each owner must submit exactly once")
                fixture.controller.stop()
            end,
        },
        {
            name = "observes a late player once and keeps character retries idempotent",
            run = function()
                local log = {}
                local first = newPlayer("first", log)
                local fixture = newFixture({ first }, nil)
                local firstState = fixture.round.states[first]
                local second = newPlayer("second", fixture.log)
                addPlayerContext(fixture, second, nil)

                fixture.players.PlayerAdded:Fire(second)
                fixture.players.PlayerAdded:Fire(second)
                second.CharacterAdded:Fire(second.Character)
                second.CharacterAdded:Fire(second.Character)
                assert(
                    second.CharacterAdded.connectCount == 1,
                    "late player retry must connect once"
                )
                assert(
                    fixture.objectives[second].Touched.connectCount == 1,
                    "late objective must connect once"
                )
                assert(
                    fixture.round.states[first] == firstState,
                    "late join must preserve first state"
                )
                assert(submissionCount(fixture) == 0, "late join and retries must not submit")
                fixture.controller.stop()
            end,
        },
        {
            name = "removes only one player's observations and makes retained callbacks inert",
            run = function()
                local log = {}
                local first = newPlayer("first", log)
                local second = newPlayer("second", log)
                local fixture = newFixture({ first, second }, nil)
                local firstObjective = fixture.objectives[first]
                fixture.players.PlayerRemoving:Fire(first)
                fixture.players.PlayerRemoving:Fire(first)
                assert(
                    first.CharacterAdded.disconnectCount == 1,
                    "character retry must disconnect once"
                )
                assert(
                    firstObjective.Touched.disconnectCount == 1,
                    "objective touch must disconnect once"
                )

                first.CharacterAdded:FireRetained(1, first.Character)
                firstObjective.Touched:FireRetained(1, newPart(first.Character))
                assert(submissionCount(fixture) == 0, "removed callbacks must be inert")
                fixture.objectives[second].Touched:Fire(newPart(second.Character))
                assert(submissionCount(fixture) == 1, "other player must remain observable")
                fixture.controller.stop()
            end,
        },
        {
            name = "stops every signal idempotently and makes retained callbacks inert",
            run = function()
                local log = {}
                local player = newPlayer("owner", log)
                local fixture = newFixture({ player }, nil)
                local objective = fixture.objectives[player]
                fixture.controller.stop()
                fixture.controller.stop()
                assert(
                    fixture.players.PlayerAdded.disconnectCount == 1,
                    "PlayerAdded disconnects once"
                )
                assert(
                    fixture.players.PlayerRemoving.disconnectCount == 1,
                    "PlayerRemoving disconnects once"
                )
                assert(
                    player.CharacterAdded.disconnectCount == 1,
                    "Character retry disconnects once"
                )
                assert(objective.Touched.disconnectCount == 1, "objective touch disconnects once")

                fixture.players.PlayerAdded:Fire(player)
                player.CharacterAdded:FireRetained(1, player.Character)
                objective.Touched:FireRetained(1, newPart(player.Character))
                assert(submissionCount(fixture) == 0, "signals after stop must be inert")
            end,
        },
        {
            name = "exposes only stop and introduces no client remote or deferred surface",
            run = function()
                local fixture = newFixture({}, nil)
                local keys = {}
                local count = 0
                for key in fixture.controller do
                    keys[key] = true
                    count += 1
                end
                assert(keys.stop and count == 1, "controller must expose only stop")
                assert(table.isfrozen(fixture.controller), "controller must be immutable")
                assert(
                    (fixture.controller :: any).RemoteEvent == nil,
                    "controller has no RemoteEvent"
                )
                assert(
                    (fixture.controller :: any).RemoteFunction == nil,
                    "controller has no RemoteFunction"
                )
                assert((fixture.controller :: any).startTimer == nil, "controller has no timer")
                assert((fixture.controller :: any).reset == nil, "controller has no reset")
                assert((fixture.controller :: any).replay == nil, "controller has no replay")
                fixture.controller.stop()
            end,
        },
    },
}
