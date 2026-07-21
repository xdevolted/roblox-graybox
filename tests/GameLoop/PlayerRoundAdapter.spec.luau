--!strict

local PlayerRoundAdapter = require("../../src/server/GameLoop/PlayerRoundAdapter")
local PlayerRoundRegistry = require("../../src/shared/GameLoop/PlayerRoundRegistry")

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
        function connection.isConnected(_connection): boolean
            return listener.active
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

local function newPlayers(existing: { any }, onEnumerate: (() -> ())?): (any, { string })
    local log = {}
    local playerAdded = newSignal(log, "PlayerAdded")
    local playerRemoving = newSignal(log, "PlayerRemoving")
    local players = {
        PlayerAdded = playerAdded,
        PlayerRemoving = playerRemoving,
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

type Write = {
    player: any,
    name: string,
    value: any,
}

local function newWriter()
    local writes: { Write } = {}
    local function write(player: any, name: string, value: any)
        table.insert(writes, {
            player = player,
            name = name,
            value = value,
        })
        player.attributes[name] = value
    end
    return write, writes
end

local function newPlayer(name: string): any
    return {
        name = name,
        attributes = {},
    }
end

local function start(existing: { any }, onEnumerate: (() -> ())?)
    local players, log = newPlayers(existing, onEnumerate)
    local writer, writes = newWriter()
    local controller = PlayerRoundAdapter.start({
        players = players,
        registryFactory = PlayerRoundRegistry.new,
        setAttribute = writer,
    })
    return controller, players, log, writes
end

local attributeNames = {
    GrayboxRoundPhase = true,
    GrayboxRoundGeneration = true,
    GrayboxRoundResult = true,
    GrayboxRoundFailureReason = true,
}

return {
    suite = "Player round adapter",
    cases = {
        {
            name = "connects player signals before enumeration",
            run = function()
                local controller, _, log = start({}, nil)
                assert(log[1] == "connect:PlayerAdded", "PlayerAdded must connect first")
                assert(log[2] == "connect:PlayerRemoving", "PlayerRemoving must connect second")
                assert(log[3] == "enumerate", "enumeration must happen after both connections")
                controller.stop()
            end,
        },
        {
            name = "initializes an existing player exactly once",
            run = function()
                local player = newPlayer("first")
                local controller, _, _, writes = start({ player }, nil)
                local state = controller.getState(player)
                assert(
                    state ~= nil and state.phase == "ACTIVE",
                    "existing player must start active"
                )
                assert(state.generation == 1, "existing player must start generation one")
                assert(#writes == 4, "initial snapshot must write four attributes")
                controller.stop()
            end,
        },
        {
            name = "deduplicates enumeration and PlayerAdded races",
            run = function()
                local player = newPlayer("race")
                local players: any
                local log: { string }
                players, log = newPlayers({ player }, function()
                    players.PlayerAdded:Fire(player)
                end)
                local writer, writes = newWriter()
                local controller = PlayerRoundAdapter.start({
                    players = players,
                    registryFactory = PlayerRoundRegistry.new,
                    setAttribute = writer,
                })
                assert(log[3] == "enumerate", "test must enumerate after connections")
                assert(
                    controller.getState(player).generation == 1,
                    "race must not increment generation"
                )
                assert(#writes == 4, "race must publish one snapshot")
                players.PlayerAdded:Fire(player)
                assert(#writes == 4, "duplicate PlayerAdded must not republish")
                controller.stop()
            end,
        },
        {
            name = "keeps two players isolated",
            run = function()
                local first = newPlayer("first")
                local second = newPlayer("second")
                local controller = start({ first, second }, nil)
                local firstHandle = controller.getSessionHandle(first)
                assert(firstHandle ~= nil, "first player must have a handle")
                local accepted = controller.applyServerEvent(first, firstHandle, {
                    type = "SUCCEED",
                    generation = 1,
                })
                assert(accepted, "first result must be accepted")
                assert(controller.getState(first).result == "SUCCESS", "first player must succeed")
                assert(
                    controller.getState(second).phase == "ACTIVE",
                    "second player must stay active"
                )
                assert(
                    second.attributes.GrayboxRoundPhase == "ACTIVE",
                    "second attributes must stay active"
                )
                controller.stop()
            end,
        },
        {
            name = "writes exactly four attributes for accepted snapshots",
            run = function()
                local player = newPlayer("attributes")
                local controller, _, _, writes = start({ player }, nil)
                assert(#writes == 4, "initial snapshot must write exactly four values")
                for _, write in writes do
                    assert(attributeNames[write.name] == true, `unexpected attribute {write.name}`)
                end
                assert(player.attributes.GrayboxRoundPhase == "ACTIVE", "phase must replicate")
                assert(player.attributes.GrayboxRoundGeneration == 1, "generation must replicate")
                local handle = controller.getSessionHandle(player)
                assert(handle ~= nil, "player must have a server handle")
                local accepted = controller.applyServerEvent(player, handle, {
                    type = "FAIL",
                    generation = 1,
                    reason = "VOID",
                })
                assert(accepted, "failure must be accepted")
                assert(#writes == 8, "accepted transition must write four more values")
                assert(player.attributes.GrayboxRoundResult == "FAILURE", "result must replicate")
                assert(
                    player.attributes.GrayboxRoundFailureReason == "VOID",
                    "reason must replicate"
                )
                controller.stop()
            end,
        },
        {
            name = "does not publish rejected duplicate stale future wrong-session or invalid events",
            run = function()
                local player = newPlayer("rejections")
                local controller, _, _, writes = start({ player }, nil)
                local handle = controller.getSessionHandle(player)
                assert(handle ~= nil, "player must have a server handle")
                local wrongHandle = table.freeze({})
                local count = #writes
                local cases = {
                    { handle = handle, event = { type = "SUCCEED", generation = 0 } },
                    { handle = handle, event = { type = "SUCCEED", generation = 2 } },
                    { handle = wrongHandle, event = { type = "SUCCEED", generation = 1 } },
                    { handle = handle, event = { type = "BEGIN_RESET", generation = 1 } },
                }
                for _, case in cases do
                    local accepted = controller.applyServerEvent(player, case.handle, case.event)
                    assert(not accepted, "invalid event must reject")
                end
                assert(#writes == count, "rejected events must not write attributes")
                assert(
                    controller.applyServerEvent(
                        player,
                        handle,
                        { type = "SUCCEED", generation = 1 }
                    ),
                    "success must accept"
                )
                count = #writes
                assert(
                    not controller.applyServerEvent(
                        player,
                        handle,
                        { type = "SUCCEED", generation = 1 }
                    ),
                    "duplicate must reject"
                )
                assert(#writes == count, "duplicate must not write attributes")
                controller.stop()
            end,
        },
        {
            name = "never writes session handles to attributes",
            run = function()
                local player = newPlayer("secrecy")
                local controller, _, _, writes = start({ player }, nil)
                local handle = controller.getSessionHandle(player)
                for _, write in writes do
                    assert(write.value ~= handle, "handle must never be an attribute value")
                    assert(attributeNames[write.name] == true, "only approved names may be written")
                end
                for _, value in player.attributes do
                    assert(value ~= handle, "replicated attributes must not contain handles")
                end
                controller.stop()
            end,
        },
        {
            name = "removes and invalidates one player without affecting another",
            run = function()
                local first = newPlayer("first")
                local second = newPlayer("second")
                local controller, players, _, writes = start({ first, second }, nil)
                local firstHandle = controller.getSessionHandle(first)
                assert(firstHandle ~= nil, "removed player must begin with a handle")
                local secondState = controller.getState(second)
                players.PlayerRemoving:Fire(first)
                assert(controller.getState(first) == nil, "removed player state must disappear")
                assert(controller.getSessionHandle(first) == nil, "removed handle must disappear")
                assert(controller.getState(second) == secondState, "other player state must remain")
                local count = #writes
                assert(
                    not controller.applyServerEvent(
                        first,
                        firstHandle,
                        { type = "SUCCEED", generation = 1 }
                    ),
                    "removed handle must reject"
                )
                assert(#writes == count, "removed callback must not publish")
                controller.stop()
            end,
        },
        {
            name = "stops all connections and registry state idempotently",
            run = function()
                local player = newPlayer("stop")
                local controller, _, log, writes = start({ player }, nil)
                controller.stop()
                local count = #writes
                assert(controller.getState(player) == nil, "stopped state must be unavailable")
                assert(
                    controller.getSessionHandle(player) == nil,
                    "stopped handle must be unavailable"
                )
                assert(log[4] == "disconnect:PlayerAdded", "PlayerAdded must disconnect")
                assert(log[5] == "disconnect:PlayerRemoving", "PlayerRemoving must disconnect")
                controller.stop()
                assert(#writes == count, "second stop must not republish")
                assert(#log == 5, "second stop must not disconnect again")
            end,
        },
        {
            name = "ignores signals fired after stop",
            run = function()
                local player = newPlayer("before")
                local later = newPlayer("later")
                local controller, players, _, writes = start({ player }, nil)
                controller.stop()
                local count = #writes
                players.PlayerAdded:Fire(later)
                players.PlayerRemoving:Fire(player)
                assert(controller.getState(later) == nil, "late signal must not initialize")
                assert(#writes == count, "late signals must not publish")
            end,
        },
        {
            name = "ignores retained publication callbacks from an old session",
            run = function()
                local player = newPlayer("rejoin")
                local players = newPlayers({ player }, nil)
                local writer, writes = newWriter()
                local retainedPublisher: PlayerRoundRegistry.Publisher? = nil
                local controller = PlayerRoundAdapter.start({
                    players = players,
                    setAttribute = writer,
                    registryFactory = function(publisher)
                        retainedPublisher = publisher
                        return PlayerRoundRegistry.new(publisher)
                    end,
                })
                local oldHandle = controller.getSessionHandle(player)
                local oldState = controller.getState(player)
                assert(oldHandle ~= nil and oldState ~= nil, "old session must exist")
                players.PlayerRemoving:Fire(player)
                players.PlayerAdded:Fire(player)
                local newHandle = controller.getSessionHandle(player)
                assert(newHandle ~= nil, "rejoined player must receive a handle")
                assert(newHandle ~= oldHandle, "rejoined player must receive a new handle")
                local count = #writes
                local publisher = retainedPublisher
                assert(publisher ~= nil, "test must retain publisher")
                publisher(player, oldHandle, oldState)
                assert(#writes == count, "old publisher callback must be ignored")
                assert(
                    controller.getSessionHandle(player) == newHandle,
                    "new session must remain current"
                )
                controller.stop()
            end,
        },
        {
            name = "uses only attributes and exposes no client transition surface",
            run = function()
                local player = newPlayer("boundary")
                local controller, players, log, writes = start({ player }, nil)
                for _, entry in log do
                    assert(not entry:find("Remote"), "adapter must not use remote operations")
                end
                for _, write in writes do
                    assert(
                        attributeNames[write.name] == true,
                        "adapter must use only approved attributes"
                    )
                end
                assert(
                    (players :: any).RemoteEvent == nil and (players :: any).RemoteFunction == nil,
                    "fake surface must have no remotes"
                )
                controller.stop()
            end,
        },
    },
}
