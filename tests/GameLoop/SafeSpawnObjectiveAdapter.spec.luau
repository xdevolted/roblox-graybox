--!strict

local ObjectivePlacement = require("../../src/shared/GameLoop/ObjectivePlacement")
local SafeSpawnObjectiveAdapter = require("../../src/server/GameLoop/SafeSpawnObjectiveAdapter")

type Callback = (player: any) -> ()

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

    function signal:Fire(player: any)
        for _, listener in listeners do
            if listener.active then
                listener.callback(player)
            end
        end
    end

    return signal
end

local function newPlayers(existing: { any }, onEnumerate: (() -> ())?)
    local log = {}
    local players = {
        PlayerAdded = newSignal(log, "PlayerAdded"),
        PlayerRemoving = newSignal(log, "PlayerRemoving"),
    }

    function players:GetPlayers()
        table.insert(log, "enumerate")
        if onEnumerate ~= nil then
            onEnumerate()
        end
        return table.clone(existing)
    end

    return players, log
end

type Record = {
    spec: SafeSpawnObjectiveAdapter.InstanceSpec,
    parent: any,
    instance: any,
}

type ExpectedGuard = {
    size: { x: number, y: number, z: number },
    position: { x: number, y: number, z: number },
}

local function newInstanceFactory()
    local records: { Record } = {}
    local world = {
        Name = "Workspace",
        children = {},
    }

    local function create(spec: SafeSpawnObjectiveAdapter.InstanceSpec, parent: any): any
        local instance: any = {
            Name = spec.name,
            spec = spec,
            position = if spec.position == nil then nil else table.clone(spec.position),
            parent = parent,
            children = {},
            attributes = {},
            destroyed = false,
            destroyCount = 0,
        }

        function instance.SetAttribute(_instance, name: string, value: any)
            instance.attributes[name] = value
        end

        function instance.Destroy(_instance)
            if instance.destroyed then
                return
            end
            instance.destroyed = true
            instance.destroyCount += 1
            for _, child in instance.children do
                child:Destroy()
            end
        end

        if parent.children ~= nil then
            table.insert(parent.children, instance)
        end
        table.insert(records, {
            spec = spec,
            parent = parent,
            instance = instance,
        })
        return instance
    end

    return create, world, records
end

local function newPlayer(userId: number, preferredIndex: number): any
    local characterLog = {}
    return {
        UserId = userId,
        preferredIndex = preferredIndex,
        CharacterAdded = newSignal(characterLog, "CharacterAdded"),
        characterLog = characterLog,
    }
end

local function start(existing: { any }, onEnumerate: (() -> ())?)
    local players, signalLog = newPlayers(existing, onEnumerate)
    local createInstance, world, records = newInstanceFactory()
    local controller = SafeSpawnObjectiveAdapter.start({
        players = players,
        world = world,
        instanceFactory = createInstance,
        registryFactory = ObjectivePlacement.new,
        preferredIndex = function(player)
            return player.preferredIndex
        end,
        moveObjective = function(objective, assignment)
            objective.Name = `Objective_{assignment.slotId}`
            objective.position = {
                x = assignment.x,
                y = 0.75,
                z = assignment.z,
            }
            objective:SetAttribute("GrayboxObjectiveSlot", assignment.slotId)
        end,
    })
    return controller, players, signalLog, world, records
end

local function recordsOfKind(records: { Record }, kind: string): { Record }
    local matches = {}
    for _, record in records do
        if record.spec.kind == kind then
            table.insert(matches, record)
        end
    end
    return matches
end

return {
    suite = "Safe spawn objective adapter",
    cases = {
        {
            name = "creates the exact arena and guarded spawn descriptors once",
            run = function()
                local controller, _, _, world, records = start({}, nil)
                assert(
                    #records == 7,
                    "arena must create root, five physical Instances, and objectives container"
                )
                assert(#recordsOfKind(records, "ARENA") == 1, "one arena root is required")
                assert(#recordsOfKind(records, "PLATFORM") == 1, "one platform is required")
                assert(#recordsOfKind(records, "SPAWN") == 1, "one spawn is required")
                local guards = recordsOfKind(records, "GUARD")
                assert(#guards == 3, "exactly three guard walls are required")
                assert(
                    #recordsOfKind(records, "OBJECTIVES") == 1,
                    "one objectives container is required"
                )
                assert(#world.children == 1, "Workspace must receive only the arena root")

                local platform = recordsOfKind(records, "PLATFORM")[1].spec
                assert(
                    platform.size.x == 96 and platform.size.y == 1 and platform.size.z == 96,
                    "platform size must match plan"
                )
                assert(
                    platform.position.x == 0
                        and platform.position.y == 0
                        and platform.position.z == 0,
                    "platform position must match plan"
                )

                local spawn = recordsOfKind(records, "SPAWN")[1].spec
                assert(spawn.className == "SpawnLocation", "spawn must use SpawnLocation")
                assert(
                    spawn.size.x == 16 and spawn.size.y == 1 and spawn.size.z == 16,
                    "spawn size must match plan"
                )
                assert(
                    spawn.position.x == 0 and spawn.position.y == 1 and spawn.position.z == 0,
                    "spawn position must match plan"
                )

                local arena = recordsOfKind(records, "ARENA")[1].instance
                local expectedGuards: { [string]: ExpectedGuard } = {
                    StartBackWall = {
                        size = { x = 20, y = 4, z = 1 },
                        position = { x = 0, y = 2.5, z = -10 },
                    },
                    StartLeftWall = {
                        size = { x = 1, y = 4, z = 20 },
                        position = { x = -10, y = 2.5, z = 0 },
                    },
                    StartRightWall = {
                        size = { x = 1, y = 4, z = 20 },
                        position = { x = 10, y = 2.5, z = 0 },
                    },
                }
                local seenGuards: { [string]: any } = {}
                for _, guard in guards do
                    local name = guard.spec.name
                    local expected = expectedGuards[name]
                    assert(expected ~= nil, `unexpected guard wall {name}`)
                    assert(seenGuards[name] == nil, `duplicate guard wall {name}`)
                    assert(guard.spec.className == "Part", `{name} must be a Part`)
                    assert(guard.parent == arena, `{name} must be parented to the arena root`)
                    assert(
                        guard.spec.size.x == expected.size.x
                            and guard.spec.size.y == expected.size.y
                            and guard.spec.size.z == expected.size.z,
                        `{name} size must match plan`
                    )
                    assert(
                        guard.spec.position.x == expected.position.x
                            and guard.spec.position.y == expected.position.y
                            and guard.spec.position.z == expected.position.z,
                        `{name} position must match plan`
                    )
                    seenGuards[name] = guard.instance
                end
                assert(seenGuards.StartBackWall ~= nil, "StartBackWall is required")
                assert(seenGuards.StartLeftWall ~= nil, "StartLeftWall is required")
                assert(seenGuards.StartRightWall ~= nil, "StartRightWall is required")
                assert(
                    seenGuards.StartBackWall ~= seenGuards.StartLeftWall
                        and seenGuards.StartBackWall ~= seenGuards.StartRightWall
                        and seenGuards.StartLeftWall ~= seenGuards.StartRightWall,
                    "each expected guard wall must be a distinct Instance"
                )
                controller.stop()
            end,
        },
        {
            name = "connects player signals before enumeration",
            run = function()
                local controller, _, log = start({}, nil)
                assert(log[1] == "connect:PlayerAdded", "PlayerAdded must connect first")
                assert(log[2] == "connect:PlayerRemoving", "PlayerRemoving must connect second")
                assert(log[3] == "enumerate", "enumeration must follow both connections")
                controller.stop()
            end,
        },
        {
            name = "creates one objective for an existing player",
            run = function()
                local player = newPlayer(101, 3)
                local controller, _, _, _, records = start({ player }, nil)
                local assignment = controller.getAssignment(player)
                local objective = controller.getObjective(player)
                assert(
                    assignment ~= nil and assignment.slotId == 3,
                    "player must receive preferred slot"
                )
                assert(objective ~= nil, "player must receive objective")
                assert(
                    objective.attributes.GrayboxObjectiveOwnerUserId == 101,
                    "objective owner metadata must match"
                )
                assert(
                    objective.attributes.GrayboxObjectiveSlot == 3,
                    "objective slot metadata must match"
                )
                local objectiveSpec = recordsOfKind(records, "OBJECTIVE")[1].spec
                assert(
                    objectiveSpec.size.x == 10
                        and objectiveSpec.size.y == 0.5
                        and objectiveSpec.size.z == 10,
                    "objective size must match plan"
                )
                assert(
                    objectiveSpec.position.x == 30
                        and objectiveSpec.position.y == 0.75
                        and objectiveSpec.position.z == -30,
                    "objective position must match assignment"
                )
                controller.stop()
            end,
        },
        {
            name = "deduplicates enumeration and PlayerAdded races",
            run = function()
                local player = newPlayer(102, 1)
                local players: any
                local signalLog: { string }
                players, signalLog = newPlayers({ player }, function()
                    players.PlayerAdded:Fire(player)
                end)
                local createInstance, world, records = newInstanceFactory()
                local controller = SafeSpawnObjectiveAdapter.start({
                    players = players,
                    world = world,
                    instanceFactory = createInstance,
                    registryFactory = ObjectivePlacement.new,
                    preferredIndex = function(target)
                        return target.preferredIndex
                    end,
                })
                assert(signalLog[3] == "enumerate", "test must exercise enumeration race")
                local objective = controller.getObjective(player)
                assert(objective ~= nil, "race player must receive objective")
                assert(#recordsOfKind(records, "OBJECTIVE") == 1, "race must create one objective")
                players.PlayerAdded:Fire(player)
                assert(
                    controller.getObjective(player) == objective,
                    "duplicate signal must preserve identity"
                )
                assert(
                    #recordsOfKind(records, "OBJECTIVE") == 1,
                    "duplicate signal must not create objective"
                )
                controller.stop()
            end,
        },
        {
            name = "keeps a late second player isolated",
            run = function()
                local first = newPlayer(103, 1)
                local second = newPlayer(104, 1)
                local controller, players = start({ first }, nil)
                local firstAssignment = controller.getAssignment(first)
                local firstObjective = controller.getObjective(first)
                players.PlayerAdded:Fire(second)
                local secondAssignment = controller.getAssignment(second)
                assert(
                    firstAssignment ~= nil and secondAssignment ~= nil,
                    "both players must be assigned"
                )
                assert(
                    firstAssignment.slotId ~= secondAssignment.slotId,
                    "players must own distinct slots"
                )
                assert(
                    controller.getAssignment(first) == firstAssignment,
                    "late join must preserve first assignment"
                )
                assert(
                    controller.getObjective(first) == firstObjective,
                    "late join must preserve first objective"
                )
                assert(
                    controller.getObjective(second) ~= firstObjective,
                    "objective identities must be distinct"
                )
                controller.stop()
            end,
        },
        {
            name = "does not observe character reloads",
            run = function()
                local player = newPlayer(105, 4)
                local controller = start({ player }, nil)
                local assignment = controller.getAssignment(player)
                local objective = controller.getObjective(player)
                player.CharacterAdded:Fire({})
                assert(#player.characterLog == 0, "adapter must not connect CharacterAdded")
                assert(
                    controller.getAssignment(player) == assignment,
                    "character reload must not reassign"
                )
                assert(
                    controller.getObjective(player) == objective,
                    "character reload must not replace objective"
                )
                controller.stop()
            end,
        },
        {
            name = "removes only the addressed player",
            run = function()
                local first = newPlayer(106, 1)
                local second = newPlayer(107, 1)
                local controller, players = start({ first, second }, nil)
                local firstAssignment = controller.getAssignment(first)
                local firstObjective = controller.getObjective(first)
                local secondObjective = controller.getObjective(second)
                players.PlayerRemoving:Fire(second)
                assert(controller.getAssignment(second) == nil, "removed assignment must disappear")
                assert(
                    controller.getObjective(second) == nil,
                    "removed objective lookup must disappear"
                )
                assert(secondObjective.destroyed, "removed objective Instance must be destroyed")
                assert(
                    controller.getAssignment(first) == firstAssignment,
                    "other assignment must remain"
                )
                assert(
                    controller.getObjective(first) == firstObjective,
                    "other objective identity must remain"
                )
                assert(not firstObjective.destroyed, "other objective must stay alive")
                players.PlayerRemoving:Fire(second)
                assert(secondObjective.destroyCount == 1, "repeated removal must not destroy twice")
                controller.stop()
            end,
        },
        {
            name = "rejects a ninth player without changing existing objectives",
            run = function()
                local existing = {}
                for index = 1, 8 do
                    table.insert(existing, newPlayer(200 + index, 1))
                end
                local controller, players, _, _, records = start(existing, nil)
                local objectives = {}
                for index, player in existing do
                    objectives[index] = controller.getObjective(player)
                    assert(objectives[index] ~= nil, "first eight players need objectives")
                end

                local ninth = newPlayer(209, 1)
                players.PlayerAdded:Fire(ninth)
                assert(
                    controller.getAssignment(ninth) == nil,
                    "ninth player must remain unassigned"
                )
                assert(
                    controller.getObjective(ninth) == nil,
                    "ninth player must receive no objective"
                )
                assert(
                    #recordsOfKind(records, "OBJECTIVE") == 8,
                    "overflow must not create an objective"
                )
                for index, player in existing do
                    assert(
                        controller.getObjective(player) == objectives[index],
                        "overflow must preserve objective identities"
                    )
                end
                controller.stop()
            end,
        },
        {
            name = "stops cleanup idempotently and ignores later signals",
            run = function()
                local player = newPlayer(108, 1)
                local later = newPlayer(109, 2)
                local controller, players, log, _, records = start({ player }, nil)
                local objective = controller.getObjective(player)
                local arena = recordsOfKind(records, "ARENA")[1].instance
                controller.stop()
                assert(
                    objective.destroyed and objective.destroyCount == 1,
                    "stop must destroy objective once"
                )
                assert(arena.destroyed and arena.destroyCount == 1, "stop must destroy arena once")
                assert(
                    table.find(log, "disconnect:PlayerAdded") ~= nil,
                    "stop must disconnect PlayerAdded"
                )
                assert(
                    table.find(log, "disconnect:PlayerRemoving") ~= nil,
                    "stop must disconnect PlayerRemoving"
                )
                assert(
                    controller.getAssignment(player) == nil,
                    "stopped assignment lookup must be nil"
                )
                assert(
                    controller.getObjective(player) == nil,
                    "stopped objective lookup must be nil"
                )
                controller.stop()
                assert(
                    objective.destroyCount == 1 and arena.destroyCount == 1,
                    "second stop must be a no-op"
                )
                players.PlayerAdded:Fire(later)
                players.PlayerRemoving:Fire(player)
                assert(controller.getObjective(later) == nil, "signals after stop must do nothing")
            end,
        },
        {
            name = "exposes only read-only seams and creates no remote or lifecycle surface",
            run = function()
                local controller, players, _, _, records = start({}, nil)
                local keys = {}
                local keyCount = 0
                for key in controller do
                    keys[key] = true
                    keyCount += 1
                end
                assert(
                    keys.getAssignment
                        and keys.getObjective
                        and keys.repositionObjective
                        and keys.stop,
                    "approved controller seams must exist"
                )
                assert(keyCount == 4, "controller must expose only four approved seams")
                assert(
                    (controller :: any).applyServerEvent == nil,
                    "controller must expose no lifecycle transition"
                )
                assert(
                    (controller :: any).RemoteEvent == nil
                        and (controller :: any).RemoteFunction == nil,
                    "controller must expose no remotes"
                )
                assert(
                    (players :: any).RemoteEvent == nil and (players :: any).RemoteFunction == nil,
                    "Players seam must contain no remotes"
                )
                for _, record in records do
                    assert(
                        record.spec.className ~= "RemoteEvent"
                            and record.spec.className ~= "RemoteFunction",
                        "adapter must create no remotes"
                    )
                end
                controller.stop()
            end,
        },
        {
            name = "repositions the same objective and updates only replay placement metadata",
            run = function()
                local player = newPlayer(110, 1)
                local controller = start({ player }, nil)
                local originalAssignment = controller.getAssignment(player)
                local objective = controller.getObjective(player)
                local replay, rejection = controller.repositionObjective(player)
                assert(replay ~= nil and rejection == nil, "reposition must succeed")
                assert(replay.slotId == 2, "reposition must advance to next free slot")
                assert(replay.slotId ~= originalAssignment.slotId, "reposition must move")
                assert(controller.getObjective(player) == objective, "identity must be preserved")
                assert(controller.getAssignment(player) == replay, "assignment must update")
                assert(objective.Name == "Objective_2", "objective name must update")
                assert(
                    objective.position.x == 0
                        and objective.position.y == 0.75
                        and objective.position.z == -30,
                    "objective position must match replay assignment"
                )
                assert(
                    objective.attributes.GrayboxObjectiveOwnerUserId == 110,
                    "owner metadata must remain unchanged"
                )
                assert(objective.attributes.GrayboxObjectiveSlot == 2, "slot metadata must update")
                controller.stop()
            end,
        },
        {
            name = "repositions only the addressed player's objective",
            run = function()
                local first = newPlayer(111, 1)
                local second = newPlayer(112, 2)
                local controller = start({ first, second }, nil)
                local firstObjective = controller.getObjective(first)
                local secondObjective = controller.getObjective(second)
                local secondAssignment = controller.getAssignment(second)
                local replay = controller.repositionObjective(first)
                assert(replay ~= nil and replay.slotId == 3, "occupied slot must be skipped")
                assert(
                    controller.getObjective(first) == firstObjective,
                    "first identity must remain"
                )
                assert(
                    controller.getObjective(second) == secondObjective,
                    "other objective identity must remain"
                )
                assert(
                    controller.getAssignment(second) == secondAssignment,
                    "other assignment must remain"
                )
                assert(
                    secondObjective.attributes.GrayboxObjectiveSlot == 2,
                    "other metadata must remain"
                )
                controller.stop()
            end,
        },
        {
            name = "repositions consecutively and uses full-capacity fallback",
            run = function()
                local playersList = {}
                for index = 1, 8 do
                    playersList[index] = newPlayer(300 + index, index)
                end
                local controller = start(playersList, nil)
                local firstObjective = controller.getObjective(playersList[1])
                local firstReplay = controller.repositionObjective(playersList[1])
                assert(
                    firstReplay ~= nil and firstReplay.slotId == 2,
                    "full-capacity replay must use next occupied slot"
                )
                local secondReplay = controller.repositionObjective(playersList[1])
                assert(
                    secondReplay ~= nil and secondReplay.slotId ~= firstReplay.slotId,
                    "consecutive replay must exclude previous slot"
                )
                assert(
                    controller.getObjective(playersList[1]) == firstObjective,
                    "fallback must retain objective identity"
                )
                for index = 2, 8 do
                    assert(
                        controller.getAssignment(playersList[index]).slotId == index,
                        "fallback must not move another assignment"
                    )
                end
                controller.stop()
            end,
        },
        {
            name = "rejects unknown removed and stopped reposition requests without writes",
            run = function()
                local player = newPlayer(113, 1)
                local unknown = newPlayer(114, 2)
                local controller, players = start({ player }, nil)
                local objective = controller.getObjective(player)
                local unknownReplay, unknownRejection = controller.repositionObjective(unknown)
                assert(
                    unknownReplay == nil and unknownRejection == "UNKNOWN_PLAYER",
                    "unknown reposition must reject"
                )
                assert(objective.attributes.GrayboxObjectiveSlot == 1, "unknown must not write")

                players.PlayerRemoving:Fire(player)
                local removedReplay, removedRejection = controller.repositionObjective(player)
                assert(
                    removedReplay == nil and removedRejection == "UNKNOWN_PLAYER",
                    "removed reposition must reject"
                )
                controller.stop()
                local stoppedReplay, stoppedRejection = controller.repositionObjective(player)
                assert(
                    stoppedReplay == nil and stoppedRejection == "DESTROYED",
                    "stopped reposition must reject"
                )
            end,
        },
        {
            name = "adds only the approved server replay seam",
            run = function()
                local controller, players = start({}, nil)
                local keys = {}
                local count = 0
                for key in controller do
                    keys[key] = true
                    count += 1
                end
                assert(
                    keys.getAssignment
                        and keys.getObjective
                        and keys.repositionObjective
                        and keys.stop,
                    "all approved seams must exist"
                )
                assert(count == 4, "no extra controller seam is permitted")
                assert(
                    (controller :: any).applyServerEvent == nil
                        and (controller :: any).startTimer == nil,
                    "objective controller must expose no lifecycle or timer authority"
                )
                assert(
                    (players :: any).RemoteEvent == nil and (players :: any).RemoteFunction == nil,
                    "replay seam must introduce no remote"
                )
                controller.stop()
            end,
        },
    },
}
