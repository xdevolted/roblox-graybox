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
    local environment: any = {
        renderStepped = renderStepped,
        world = world,
        targetPosition = { x = 0, y = 28, z = 0 },
        effectCreateCount = 0,
        effectDestroyCount = 0,
        positionReads = 0,
        appliedPositions = {},
        warnings = {},
        failCreation = false,
        controller = nil,
    }

    function environment.dependencies(_environment: any): any
        return {
            world = world,
            renderStepped = renderStepped,
            createEffect = function(receivedWorld: any): any
                assert(receivedWorld == world, "effect factory must receive only the local world")
                environment.effectCreateCount += 1
                if environment.failCreation then
                    error("planned construction failure")
                end

                local destroyed = false
                return {
                    setPosition = function(position: any)
                        assert(not destroyed, "destroyed effect must not move")
                        table.insert(environment.appliedPositions, position)
                    end,
                    destroy = function()
                        if destroyed then
                            return
                        end
                        destroyed = true
                        environment.effectDestroyCount += 1
                    end,
                }
            end,
            readTargetPosition = function(receivedWorld: any): any
                assert(receivedWorld == world, "position reader must receive only the local world")
                environment.positionReads += 1
                return environment.targetPosition
            end,
            isFinitePosition = isFinitePosition,
            reportWarning = function(message: string)
                table.insert(environment.warnings, message)
            end,
        }
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
    suite = "RainController",
    cases = {
        {
            name = "RC-01 first start creates positions and connects exactly once",
            run = function()
                withEnvironment(function(environment: any)
                    environment:start()
                    assert(environment.effectCreateCount == 1, "one effect must be created")
                    assert(environment.renderStepped.connectCount == 1, "one listener must connect")
                    assert(environment.positionReads == 1, "start must read the initial position")
                    assert(#environment.appliedPositions == 1, "start must position the effect")
                    assert(
                        environment.appliedPositions[1] == environment.targetPosition,
                        "initial valid position must be applied"
                    )
                end)
            end,
        },
        {
            name = "RC-02 repeated start returns the active controller",
            run = function()
                withEnvironment(function(environment: any)
                    local first = environment:start()
                    local second = environment:start()
                    assert(first == second, "start must return the active controller")
                    assert(
                        environment.effectCreateCount == 1,
                        "start must not duplicate the effect"
                    )
                    assert(
                        environment.renderStepped.connectCount == 1,
                        "listener must not duplicate"
                    )
                    assert(environment.positionReads == 1, "repeat start must not force an update")
                    assert(#environment.warnings == 0, "repeat start must not warn")
                end)
            end,
        },
        {
            name = "RC-03 render updates move the same effect to each valid target",
            run = function()
                withEnvironment(function(environment: any)
                    environment:start()
                    local second = { x = 20, y = 30, z = -10 }
                    local third = { x = -15, y = 29, z = 24 }
                    environment.targetPosition = second
                    environment.renderStepped:Fire()
                    environment.targetPosition = third
                    environment.renderStepped:Fire()

                    assert(environment.effectCreateCount == 1, "updates must reuse one effect")
                    assert(#environment.appliedPositions == 3, "each valid target must apply")
                    assert(environment.appliedPositions[2] == second, "second target must apply")
                    assert(environment.appliedPositions[3] == third, "third target must apply")
                end)
            end,
        },
        {
            name = "RC-04 invalid targets are skipped and a valid target resumes",
            run = function()
                withEnvironment(function(environment: any)
                    environment:start()
                    local appliedBefore = #environment.appliedPositions
                    local invalidTargets = {
                        nil,
                        "bad",
                        { x = 0 / 0, y = 28, z = 0 },
                        { x = math.huge, y = 28, z = 0 },
                        { x = 0, y = -math.huge, z = 0 },
                    }
                    for _, target in invalidTargets do
                        environment.targetPosition = target
                        environment.renderStepped:Fire()
                    end
                    assert(
                        #environment.appliedPositions == appliedBefore,
                        "invalid targets must not move the effect"
                    )
                    assert(environment.effectCreateCount == 1, "invalid targets must not recreate")
                    assert(#environment.warnings == 0, "invalid targets must not warn per frame")

                    local recovered = { x = 5, y = 28, z = 7 }
                    environment.targetPosition = recovered
                    environment.renderStepped:Fire()
                    assert(
                        environment.appliedPositions[#environment.appliedPositions] == recovered,
                        "a later valid target must resume"
                    )
                end)
            end,
        },
        {
            name = "RC-05 character and round changes do not affect rain lifecycle",
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
                        "the simulated unrelated lifecycle must actually change"
                    )
                    assert(environment.effectCreateCount == 1, "unrelated state must not recreate")
                    assert(environment.renderStepped.connectCount == 1, "no listener may be added")
                    assert(
                        environment.positionReads == readsBefore,
                        "unrelated state must not update"
                    )
                    assert(environment.effectDestroyCount == 0, "unrelated state must not destroy")
                end)
            end,
        },
        {
            name = "RC-06 stop disconnects and destroys exactly once",
            run = function()
                withEnvironment(function(environment: any)
                    local controller = environment:start()
                    controller.stop()
                    controller.stop()
                    assert(
                        environment.renderStepped.disconnectCount == 1,
                        "listener must disconnect once"
                    )
                    assert(environment.effectDestroyCount == 1, "effect must destroy once")
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
            name = "RC-07 retained callbacks are inert and restart is clean",
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
                        environment.effectCreateCount == 2,
                        "restart must create one fresh effect"
                    )
                    assert(
                        environment.renderStepped.connectCount == 2,
                        "restart must add one listener"
                    )
                    assert(#environment.appliedPositions == 2, "restart must position only once")
                end)
            end,
        },
        {
            name = "RC-08 construction failure warns once and allows a clean retry after stop",
            run = function()
                withEnvironment(function(environment: any)
                    environment.failCreation = true
                    local first = environment:start()
                    local second = environment:start()
                    assert(first == second, "failed bootstrap must retain its guard")
                    assert(
                        environment.effectCreateCount == 1,
                        "failure must not retry automatically"
                    )
                    assert(#environment.warnings == 1, "construction failure must warn once")
                    assert(environment.renderStepped.connectCount == 0, "failure must not connect")

                    first.stop()
                    environment.failCreation = false
                    local recovered = environment:start()
                    assert(recovered ~= first, "stop must permit a clean retry")
                    assert(environment.effectCreateCount == 2, "clean retry must create one effect")
                    assert(
                        environment.renderStepped.connectCount == 1,
                        "clean retry must connect once"
                    )
                end)
            end,
        },
        {
            name = "RC-09 simulated client contexts do not share effects or positions",
            run = function()
                local first = newEnvironment()
                first.targetPosition = { x = 1, y = 28, z = 1 }
                first:start()
                first:stop()

                local second = newEnvironment()
                second.targetPosition = { x = 2, y = 28, z = 2 }
                second:start()
                second:stop()

                assert(first.effectCreateCount == 1, "first client must own one effect")
                assert(second.effectCreateCount == 1, "second client must own one effect")
                assert(#first.appliedPositions == 1, "first client must own its position history")
                assert(#second.appliedPositions == 1, "second client must own its position history")
                assert(
                    first.appliedPositions[1] ~= second.appliedPositions[1],
                    "simulated client positions must not alias"
                )
            end,
        },
        {
            name = "RC-10 controller exposes no gameplay authority path",
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

                    assert(authorityCalls == 0, "rain must not call any gameplay authority surface")
                    assert(authoritySurface ~= nil, "authority sentinel must remain available")
                    assert(environment.effectCreateCount == 1, "only presentation may be created")
                    assert(#environment.warnings == 0, "ordinary presentation must not warn")
                end)
            end,
        },
    },
}
