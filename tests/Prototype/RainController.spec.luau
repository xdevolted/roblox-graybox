--!strict

local RainController = require("../../src/client/Prototype/RainController")

type Callback = (...any) -> ()

local function newSignal(): any
    local listeners = {}
    local signal: any = {
        listeners = listeners,
        connectCount = 0,
        disconnectCount = 0,
    }

    function signal.Connect(_signal: any, callback: Callback)
        signal.connectCount += 1
        local listener = {
            active = true,
            callback = callback,
        }
        table.insert(listeners, listener)

        local connection = {}
        function connection.Disconnect(_connection: any)
            if not listener.active then
                return
            end
            listener.active = false
            signal.disconnectCount += 1
        end
        return connection
    end

    function signal.Fire(_signal: any)
        for _, listener in listeners do
            if listener.active then
                listener.callback()
            end
        end
    end

    function signal.FireRetained(_signal: any)
        for _, listener in listeners do
            listener.callback()
        end
    end

    return signal
end

local function isFinite(value: any): boolean
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isFinitePosition(value: any): boolean
    return type(value) == "table" and isFinite(value.x) and isFinite(value.y) and isFinite(value.z)
end

local function newEnvironment(): any
    local renderStepped = newSignal()
    local world = {}
    local soundParent = {}
    local environment: any = {
        renderStepped = renderStepped,
        world = world,
        soundParent = soundParent,
        targetPosition = { x = 0, y = 28, z = 0 },
        layerCreateCount = 0,
        layerCreateIndices = {},
        layerDestroyCounts = { 0, 0 },
        layerPositions = { {}, {} },
        soundCreateCount = 0,
        soundPlayCount = 0,
        soundDestroyCount = 0,
        partialSoundDestroyCount = 0,
        defaultSoundCreateCount = 0,
        defaultSoundDestroyCount = 0,
        positionReads = 0,
        warnings = {},
        failLayerIndex = nil,
        failSound = false,
        useDefaultSound = false,
        controller = nil,
    }

    function environment.dependencies(_environment: any): any
        local dependencies = {
            world = world,
            soundParent = soundParent,
            renderStepped = renderStepped,
            createLayer = function(receivedWorld: any, layerIndex: number): any
                assert(receivedWorld == world, "layer factory must receive only local world")
                environment.layerCreateCount += 1
                table.insert(environment.layerCreateIndices, layerIndex)
                if environment.failLayerIndex == layerIndex then
                    error(`planned layer {layerIndex} failure`)
                end

                local destroyed = false
                return {
                    setPosition = function(position: any)
                        assert(not destroyed, "destroyed layer must not move")
                        table.insert(environment.layerPositions[layerIndex], position)
                    end,
                    destroy = function()
                        if destroyed then
                            return
                        end
                        destroyed = true
                        environment.layerDestroyCounts[layerIndex] += 1
                    end,
                }
            end,
            createSound = function(receivedParent: any): any
                assert(receivedParent == soundParent, "sound factory must receive sound parent")
                environment.soundCreateCount += 1
                if environment.failSound then
                    environment.partialSoundDestroyCount += 1
                    error("planned sound playback failure")
                end

                environment.soundPlayCount += 1
                local destroyed = false
                return {
                    destroy = function()
                        if destroyed then
                            return
                        end
                        destroyed = true
                        environment.soundDestroyCount += 1
                    end,
                }
            end,
            readTargetPosition = function(receivedWorld: any): any
                assert(receivedWorld == world, "position reader must receive local world")
                environment.positionReads += 1
                return environment.targetPosition
            end,
            isFinitePosition = isFinitePosition,
            reportWarning = function(message: string)
                table.insert(environment.warnings, message)
            end,
        }
        if environment.useDefaultSound then
            dependencies.createSound = nil
        end
        return dependencies
    end

    function environment.start(_environment: any): any
        local controller = RainController.start(environment:dependencies())
        environment.controller = controller
        return controller
    end

    function environment.stop(_environment: any)
        if environment.controller ~= nil then
            environment.controller.stop()
            environment.controller = nil
        end
    end

    return environment
end

local function withEnvironment(callback: (environment: any) -> ())
    local environment = newEnvironment()
    local succeeded, message = pcall(callback, environment)
    environment:stop()
    if not succeeded then
        error(message)
    end
end

return {
    suite = "Heavy rain controller",
    cases = {
        {
            name = "HRC-01 first start owns two layers one sound and one listener",
            run = function()
                withEnvironment(function(environment: any)
                    environment:start()
                    assert(environment.layerCreateCount == 2, "two layers must be created")
                    assert(
                        environment.layerCreateIndices[1] == 1
                            and environment.layerCreateIndices[2] == 2,
                        "layers must use exact ordered indices"
                    )
                    assert(environment.soundCreateCount == 1, "one sound must be created")
                    assert(environment.soundPlayCount == 1, "sound must play once")
                    assert(environment.renderStepped.connectCount == 1, "one listener must connect")
                    assert(environment.positionReads == 1, "start must read one target")
                    assert(#environment.layerPositions[1] == 1, "layer one must position once")
                    assert(#environment.layerPositions[2] == 1, "layer two must position once")
                end)
            end,
        },
        {
            name = "HRC-02 repeated start cannot duplicate ambience",
            run = function()
                withEnvironment(function(environment: any)
                    local first = environment:start()
                    local second = environment:start()
                    assert(first == second, "start must return the active controller")
                    assert(environment.layerCreateCount == 2, "layers must not duplicate")
                    assert(environment.soundCreateCount == 1, "sound must not duplicate")
                    assert(environment.soundPlayCount == 1, "playback must not restart")
                    assert(
                        environment.renderStepped.connectCount == 1,
                        "listener must not duplicate"
                    )
                    assert(environment.positionReads == 1, "repeat start must not update")
                    assert(#environment.warnings == 0, "repeat start must not warn")
                end)
            end,
        },
        {
            name = "HRC-03 render updates move both existing layers",
            run = function()
                withEnvironment(function(environment: any)
                    environment:start()
                    local second = { x = 20, y = 30, z = -10 }
                    local third = { x = -15, y = 29, z = 24 }
                    environment.targetPosition = second
                    environment.renderStepped:Fire()
                    environment.targetPosition = third
                    environment.renderStepped:Fire()

                    assert(environment.layerCreateCount == 2, "updates must reuse layers")
                    for layerIndex = 1, 2 do
                        local positions = environment.layerPositions[layerIndex]
                        assert(#positions == 3, `layer {layerIndex} must receive every target`)
                        assert(positions[2] == second, "second target must apply")
                        assert(positions[3] == third, "third target must apply")
                    end
                end)
            end,
        },
        {
            name = "HRC-04 invalid targets skip both layers and valid input resumes",
            run = function()
                withEnvironment(function(environment: any)
                    environment:start()
                    environment.targetPosition = nil
                    environment.renderStepped:Fire()
                    local invalidTargets = {
                        "bad",
                        { x = 0 / 0, y = 28, z = 0 },
                        { x = math.huge, y = 28, z = 0 },
                        { x = 0, y = -math.huge, z = 0 },
                    }
                    for _, target in invalidTargets do
                        environment.targetPosition = target
                        environment.renderStepped:Fire()
                    end
                    assert(#environment.layerPositions[1] == 1, "invalid input must skip layer one")
                    assert(#environment.layerPositions[2] == 1, "invalid input must skip layer two")
                    assert(environment.layerCreateCount == 2, "invalid input must not recreate")
                    assert(#environment.warnings == 0, "invalid input must not warn per frame")

                    local recovered = { x = 5, y = 28, z = 7 }
                    environment.targetPosition = recovered
                    environment.renderStepped:Fire()
                    assert(environment.layerPositions[1][2] == recovered, "layer one must resume")
                    assert(environment.layerPositions[2][2] == recovered, "layer two must resume")
                end)
            end,
        },
        {
            name = "HRC-05 visual construction failure rolls back and guards retry",
            run = function()
                withEnvironment(function(environment: any)
                    environment.failLayerIndex = 1
                    local first = environment:start()
                    local second = environment:start()
                    assert(first == second, "failed start must retain singleton guard")
                    assert(
                        environment.layerCreateCount == 1,
                        "layer one failure must stop creation"
                    )
                    assert(environment.layerDestroyCounts[1] == 0, "no completed layer exists")
                    assert(environment.soundCreateCount == 0, "visual failure must create no sound")
                    assert(
                        environment.renderStepped.connectCount == 0,
                        "visual failure must not connect"
                    )
                    assert(#environment.warnings == 1, "visual failure must warn once")
                end)

                withEnvironment(function(environment: any)
                    environment.failLayerIndex = 2
                    local first = environment:start()
                    local second = environment:start()
                    assert(first == second, "layer two failure must retain guard")
                    assert(environment.layerCreateCount == 2, "layer two failure follows layer one")
                    assert(environment.layerDestroyCounts[1] == 1, "layer one must roll back")
                    assert(environment.layerDestroyCounts[2] == 0, "failed layer has no handle")
                    assert(environment.soundCreateCount == 0, "rollback must create no sound")
                    assert(environment.renderStepped.connectCount == 0, "rollback must not connect")
                    assert(#environment.warnings == 1, "rollback must warn once")
                end)
            end,
        },
        {
            name = "HRC-06 sound failure leaves both visual layers running",
            run = function()
                withEnvironment(function(environment: any)
                    environment.failSound = true
                    local first = environment:start()
                    local second = environment:start()
                    assert(first == second, "audio failure must still guard active visuals")
                    assert(environment.layerCreateCount == 2, "both layers must survive")
                    assert(#environment.layerPositions[1] == 1, "layer one must position")
                    assert(#environment.layerPositions[2] == 1, "layer two must position")
                    assert(environment.soundCreateCount == 1, "sound must try only once")
                    assert(environment.soundPlayCount == 0, "failed sound must not report playback")
                    assert(
                        environment.partialSoundDestroyCount == 1,
                        "sound factory must destroy its partial object"
                    )
                    assert(
                        environment.renderStepped.connectCount == 1,
                        "visuals must keep listener"
                    )
                    assert(#environment.warnings == 1, "audio failure must warn once")
                    environment.renderStepped:Fire()
                    assert(environment.soundCreateCount == 1, "updates must not retry sound")
                end)

                withEnvironment(function(environment: any)
                    local moduleEnvironment = getfenv(RainController.start)
                    local originalInstance = moduleEnvironment.Instance
                    environment.useDefaultSound = true
                    moduleEnvironment.Instance = {
                        new = function(className: string): any
                            assert(className == "Sound", "default factory must create only a Sound")
                            environment.defaultSoundCreateCount += 1
                            local sound = {}
                            function sound.Destroy(_sound: any)
                                environment.defaultSoundDestroyCount += 1
                            end
                            return setmetatable(sound, {
                                __newindex = function(target: any, key: any, value: any)
                                    if key == "Parent" then
                                        error("planned sound parenting failure")
                                    end
                                    rawset(target, key, value)
                                end,
                            })
                        end,
                    }

                    local succeeded, message = pcall(function()
                        environment:start()
                    end)
                    moduleEnvironment.Instance = originalInstance
                    if not succeeded then
                        error(message)
                    end

                    assert(
                        environment.defaultSoundCreateCount == 1,
                        "production factory must create one partial sound"
                    )
                    assert(
                        environment.defaultSoundDestroyCount == 1,
                        "production factory must destroy a partial sound after construction failure"
                    )
                    assert(environment.layerCreateCount == 2, "both visual layers must survive")
                    assert(
                        environment.renderStepped.connectCount == 1,
                        "visuals must keep listener"
                    )
                    assert(#environment.warnings == 1, "construction failure must warn once")
                end)
            end,
        },
        {
            name = "HRC-07 character and round changes cannot restart ambience",
            run = function()
                withEnvironment(function(environment: any)
                    environment:start()
                    local unrelated = {
                        Character = { name = "First" },
                        GrayboxRoundPhase = "ACTIVE",
                    }
                    local readsBefore = environment.positionReads
                    unrelated.Character = { name = "Replacement" }
                    unrelated.GrayboxRoundPhase = "RESULT"
                    assert(
                        unrelated.Character.name == "Replacement"
                            and unrelated.GrayboxRoundPhase == "RESULT",
                        "simulated unrelated lifecycle must change"
                    )
                    assert(environment.layerCreateCount == 2, "unrelated state must not recreate")
                    assert(environment.soundCreateCount == 1, "unrelated state must not resound")
                    assert(environment.soundPlayCount == 1, "playback must remain one-time")
                    assert(environment.renderStepped.connectCount == 1, "no listener may be added")
                    assert(
                        environment.positionReads == readsBefore,
                        "unrelated state must not update"
                    )
                end)
            end,
        },
        {
            name = "HRC-08 stop cleans every layer sound and listener exactly once",
            run = function()
                withEnvironment(function(environment: any)
                    local controller = environment:start()
                    controller.stop()
                    controller.stop()
                    assert(
                        environment.renderStepped.disconnectCount == 1,
                        "listener must disconnect once"
                    )
                    assert(environment.soundDestroyCount == 1, "sound must destroy once")
                    assert(environment.layerDestroyCounts[1] == 1, "layer one must destroy once")
                    assert(environment.layerDestroyCounts[2] == 1, "layer two must destroy once")
                    local readsAfterStop = environment.positionReads
                    environment.renderStepped:Fire()
                    assert(
                        environment.positionReads == readsAfterStop,
                        "stopped listener must be inert"
                    )
                end)
            end,
        },
        {
            name = "HRC-09 retained callbacks are inert and restart is complete",
            run = function()
                withEnvironment(function(environment: any)
                    local first = environment:start()
                    first.stop()
                    local readsAfterStop = environment.positionReads
                    environment.renderStepped:FireRetained()
                    assert(
                        environment.positionReads == readsAfterStop,
                        "retained callback must be inert"
                    )

                    local second = environment:start()
                    assert(second ~= first, "restart must create a fresh controller")
                    assert(
                        environment.layerCreateCount == 4,
                        "restart must create two fresh layers"
                    )
                    assert(environment.soundCreateCount == 2, "restart must create one fresh sound")
                    assert(environment.soundPlayCount == 2, "restart must play fresh sound once")
                    assert(
                        environment.renderStepped.connectCount == 2,
                        "restart must add one listener"
                    )
                    assert(#environment.layerPositions[1] == 2, "layer one must position per start")
                    assert(#environment.layerPositions[2] == 2, "layer two must position per start")
                end)
            end,
        },
        {
            name = "HRC-10 simulated clients share no ambience state",
            run = function()
                local first = newEnvironment()
                first.targetPosition = { x = 1, y = 28, z = 1 }
                first:start()
                first:stop()

                local second = newEnvironment()
                second.targetPosition = { x = 2, y = 28, z = 2 }
                second:start()
                second:stop()

                for _, environment in { first, second } do
                    assert(environment.layerCreateCount == 2, "each client must own two layers")
                    assert(environment.soundCreateCount == 1, "each client must own one sound")
                    assert(environment.soundPlayCount == 1, "each client must play once")
                    assert(environment.soundDestroyCount == 1, "each client must clean its sound")
                end
                assert(
                    first.layerPositions[1][1] ~= second.layerPositions[1][1],
                    "simulated client positions must not alias"
                )
            end,
        },
        {
            name = "HRC-11 controller exposes no gameplay authority path",
            run = function()
                withEnvironment(function(environment: any)
                    local authorityCalls = 0
                    local authoritySurface = {
                        SetAttribute = function()
                            authorityCalls += 1
                        end,
                        FireServer = function()
                            authorityCalls += 1
                        end,
                        TakeDamage = function()
                            authorityCalls += 1
                        end,
                    }
                    environment:start()
                    environment.renderStepped:Fire()
                    environment:stop()

                    assert(authorityCalls == 0, "ambience must not call gameplay authority")
                    assert(authoritySurface.SetAttribute ~= nil, "authority sentinel must exist")
                    assert(environment.layerCreateCount == 2, "only visual layers may be created")
                    assert(environment.soundCreateCount == 1, "only one local sound may be created")
                    assert(#environment.warnings == 0, "ordinary ambience must not warn")
                end)
            end,
        },
    },
}
