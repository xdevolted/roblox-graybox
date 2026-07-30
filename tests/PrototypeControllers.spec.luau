--!strict

local DebugHudController = require("../src/client/Prototype/DebugHudController")
local InputController = require("../src/client/Prototype/InputController")
local PrimitiveFeedbackModel = require("../src/client/Prototype/PrimitiveFeedbackModel")

type Callback = (...any) -> ()

local function newSignal(signals: { any }, name: string): any
    local listeners = {}
    local signal: any = {
        name = name,
        listeners = listeners,
        connectCount = 0,
        disconnectCount = 0,
    }
    table.insert(signals, signal)

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

    function signal.Fire(_signal: any, ...: any)
        for _, listener in listeners do
            if listener.active then
                listener.callback(...)
            end
        end
    end

    function signal.FireRetained(_signal: any, ...: any)
        for _, listener in listeners do
            listener.callback(...)
        end
    end

    return signal
end

local function newNode(signals: { any }, name: string, kind: string): any
    local children = {}
    local attributes = {}
    local attributeSignals = {}
    local node: any = {
        Name = name,
        Kind = kind,
        Parent = nil,
        Character = nil,
        LocalTransparencyModifier = 0,
        ChildAdded = newSignal(signals, `{name}.ChildAdded`),
        ChildRemoved = newSignal(signals, `{name}.ChildRemoved`),
        unauthorizedAttributeWrites = 0,
    }

    function node.GetChildren(_node: any)
        local copy = {}
        for _, child in children do
            table.insert(copy, child)
        end
        return copy
    end

    function node.AddChild(_node: any, child: any)
        table.insert(children, child)
        child.Parent = node
        node.ChildAdded:Fire(child)
    end

    function node.RemoveChild(_node: any, child: any)
        for index, current in children do
            if current == child then
                table.remove(children, index)
                child.Parent = nil
                node.ChildRemoved:Fire(child)
                return
            end
        end
    end

    function node.GetAttribute(_node: any, attributeName: string)
        return attributes[attributeName]
    end

    function node.GetAttributeChangedSignal(_node: any, attributeName: string)
        local signal = attributeSignals[attributeName]
        if signal == nil then
            signal = newSignal(signals, `{name}.{attributeName}`)
            attributeSignals[attributeName] = signal
        end
        return signal
    end

    function node.ServerSetAttribute(_node: any, attributeName: string, value: any)
        attributes[attributeName] = value
        local signal = attributeSignals[attributeName]
        if signal ~= nil then
            signal:Fire()
        end
    end

    function node.SetAttribute(_node: any, _attributeName: string, _value: any)
        node.unauthorizedAttributeWrites += 1
    end

    return node
end

local function newEnvironment(): any
    local signals = {}
    local workspace = newNode(signals, "Workspace", "Workspace")
    local localPlayer = newNode(signals, "LocalPlayer", "Player")
    localPlayer.UserId = 101
    local renderStepped = newSignal(signals, "RenderStepped")
    local deferred = {}
    local renders = {}
    local controllers = {}

    local environment: any = {
        signals = signals,
        workspace = workspace,
        localPlayer = localPlayer,
        playerGui = {},
        renderStepped = renderStepped,
        deferred = deferred,
        renders = renders,
        controllers = controllers,
        nowValue = 100,
        viewCreateCount = 0,
        viewDestroyCount = 0,
        warnings = {},
        failViewCreation = false,
    }

    function environment.makeNode(_environment: any, name: string, kind: string)
        return newNode(signals, name, kind)
    end

    function environment.addArena(_environment: any)
        local arena = newNode(signals, "GrayboxArena", "Folder")
        workspace:AddChild(arena)
        return arena
    end

    function environment.addFolder(_environment: any, arena: any)
        local folder = newNode(signals, "Objectives", "Folder")
        arena:AddChild(folder)
        return folder
    end

    function environment.addCandidate(
        _environment: any,
        folder: any,
        name: string,
        ownerUserId: any,
        originalTransparency: number?
    )
        local candidate = newNode(signals, name, "BasePart")
        candidate.LocalTransparencyModifier = originalTransparency or 0
        if ownerUserId ~= nil then
            candidate:ServerSetAttribute("GrayboxObjectiveOwnerUserId", ownerUserId)
        end
        folder:AddChild(candidate)
        return candidate
    end

    function environment.setActiveAttributes(
        _environment: any,
        generation: number,
        deadline: number
    )
        localPlayer:ServerSetAttribute("GrayboxRoundPhase", "ACTIVE")
        localPlayer:ServerSetAttribute("GrayboxRoundGeneration", generation)
        localPlayer:ServerSetAttribute("GrayboxRoundResult", nil)
        localPlayer:ServerSetAttribute("GrayboxRoundFailureReason", nil)
        localPlayer:ServerSetAttribute("GrayboxPhaseEndsAt", deadline)
    end

    function environment.flushDeferred(_environment: any)
        while #deferred > 0 do
            local callback = table.remove(deferred, 1)
            callback()
        end
    end

    function environment.totalConnects(_environment: any): number
        local total = 0
        for _, signal in signals do
            total += signal.connectCount
        end
        return total
    end

    function environment.totalDisconnects(_environment: any): number
        local total = 0
        for _, signal in signals do
            total += signal.disconnectCount
        end
        return total
    end

    function environment.totalActiveConnections(_environment: any): number
        local total = 0
        for _, signal in signals do
            for _, listener in signal.listeners do
                if listener.active then
                    total += 1
                end
            end
        end
        return total
    end

    function environment.start(_environment: any)
        local controller = DebugHudController.start({
            localPlayer = localPlayer,
            playerGui = environment.playerGui,
            workspace = workspace,
            renderStepped = renderStepped,
            now = function()
                return environment.nowValue
            end,
            present = PrimitiveFeedbackModel.present,
            createView = function(_playerGui: any)
                environment.viewCreateCount += 1
                if environment.failViewCreation then
                    error("deliberate view failure")
                end
                local destroyed = false
                return table.freeze({
                    render = function(viewModel: any)
                        assert(not destroyed, "destroyed view must not render")
                        table.insert(renders, viewModel)
                    end,
                    destroy = function()
                        if destroyed then
                            return
                        end
                        destroyed = true
                        environment.viewDestroyCount += 1
                    end,
                })
            end,
            defer = function(callback: () -> ())
                table.insert(deferred, callback)
            end,
            isBasePart = function(value: any)
                return value.Kind == "BasePart"
            end,
            reportWarning = function(message: string)
                table.insert(environment.warnings, message)
            end,
        })
        table.insert(controllers, controller)
        return controller
    end

    function environment.stopAll(_environment: any)
        for _, controller in controllers do
            controller.stop()
        end
    end

    return environment
end

local function withEnvironment(callback: (environment: any) -> ())
    local environment = newEnvironment()
    local succeeded, message = pcall(callback, environment)
    environment:stopAll()
    if not succeeded then
        error(message, 0)
    end
end

local function lastRender(environment: any): any
    return environment.renders[#environment.renders]
end

return {
    suite = "Prototype controllers",
    cases = {
        {
            name = "export callable start functions",
            run = function()
                assert(
                    type(InputController.start) == "function",
                    "InputController.start must be callable"
                )
                assert(
                    type(DebugHudController.start) == "function",
                    "DebugHudController.start must be callable"
                )
            end,
        },
        {
            name = "remain immutable",
            run = function()
                assert(table.isfrozen(InputController), "InputController must be frozen")
                assert(table.isfrozen(DebugHudController), "DebugHudController must be frozen")
            end,
        },
        {
            name = "DHC-01 matches every canonical connection-count tier",
            run = function()
                local function assertTier(setup: (any) -> (), expected: number)
                    withEnvironment(function(environment: any)
                        setup(environment)
                        environment:setActiveAttributes(1, 110)
                        environment:start()
                        assert(
                            environment:totalConnects() == expected,
                            `expected {expected} connections, got {environment:totalConnects()}`
                        )
                        assert(environment.viewCreateCount == 1, "one view must be created")
                        assert(#environment.renders >= 1, "initial snapshot must render")
                    end)
                end

                assertTier(function(_environment: any) end, 8)
                assertTier(function(environment: any)
                    environment:addArena()
                end, 10)
                assertTier(function(environment: any)
                    local arena = environment:addArena()
                    environment:addFolder(arena)
                end, 12)
                assertTier(function(environment: any)
                    local arena = environment:addArena()
                    local folder = environment:addFolder(arena)
                    environment:addCandidate(folder, "Owned", 101, nil)
                    environment:addCandidate(folder, "Foreign", 202, nil)
                end, 14)
            end,
        },
        {
            name = "DHC-02 prevents duplicate bootstrap",
            run = function()
                withEnvironment(function(environment: any)
                    environment:setActiveAttributes(1, 110)
                    local first = environment:start()
                    local connects = environment:totalConnects()
                    local second = environment:start()
                    assert(first == second, "duplicate start must return active controller")
                    assert(environment.viewCreateCount == 1, "duplicate start must not create UI")
                    assert(
                        environment:totalConnects() == connects,
                        "duplicate start must not connect signals"
                    )
                end)
            end,
        },
        {
            name = "DHC-03 coalesces attribute bursts into one full reread",
            run = function()
                withEnvironment(function(environment: any)
                    environment:setActiveAttributes(1, 110)
                    environment:start()
                    local rendersBefore = #environment.renders

                    environment.localPlayer:ServerSetAttribute("GrayboxRoundPhase", "RESULT")
                    environment.localPlayer:ServerSetAttribute("GrayboxRoundResult", "SUCCESS")
                    environment.localPlayer:ServerSetAttribute("GrayboxPhaseEndsAt", 102)
                    assert(#environment.deferred == 1, "attribute burst must schedule once")
                    assert(
                        #environment.renders == rendersBefore,
                        "deferred burst must not render early"
                    )

                    environment:flushDeferred()
                    assert(
                        #environment.renders == rendersBefore + 1,
                        "coalesced burst must render once"
                    )
                    assert(lastRender(environment).phase == "RESULT", "full reread must converge")

                    environment.localPlayer:ServerSetAttribute("GrayboxPhaseEndsAt", 101)
                    assert(#environment.deferred == 1, "pending flag must clear after callback")
                end)
            end,
        },
        {
            name = "DHC-04 treats countdown zero as presentation only",
            run = function()
                withEnvironment(function(environment: any)
                    environment:setActiveAttributes(1, 110)
                    environment:start()
                    environment.nowValue = 120
                    environment.renderStepped:Fire()

                    local view = lastRender(environment)
                    assert(view.phase == "ACTIVE", "client time must not change phase")
                    assert(view.remainingSeconds == 0, "expired display must render zero")
                    assert(
                        environment.localPlayer.unauthorizedAttributeWrites == 0,
                        "controller must not write Player attributes"
                    )
                end)
            end,
        },
        {
            name = "DHC-05 binds existing hierarchy and shows only one owned objective",
            run = function()
                withEnvironment(function(environment: any)
                    local arena = environment:addArena()
                    local folder = environment:addFolder(arena)
                    local owned = environment:addCandidate(folder, "Owned", 101, 0.2)
                    local foreign = environment:addCandidate(folder, "Foreign", 202, 0.3)
                    local unresolved = environment:addCandidate(folder, "Unresolved", nil, 0.4)
                    environment:setActiveAttributes(1, 110)
                    environment:start()

                    assert(owned.LocalTransparencyModifier == 0, "owned objective must show")
                    assert(foreign.LocalTransparencyModifier == 1, "foreign objective must hide")
                    assert(
                        unresolved.LocalTransparencyModifier == 1,
                        "unresolved objective must hide"
                    )
                    assert(
                        lastRender(environment).text:find("REACH YOUR GLOWING ZONE", 1, true) ~= nil,
                        "exactly one owner match must be ready"
                    )
                end)
            end,
        },
        {
            name = "DHC-06 converges through late hierarchy and owner replication",
            run = function()
                withEnvironment(function(environment: any)
                    environment:setActiveAttributes(1, 110)
                    environment:start()
                    assert(environment:totalConnects() == 8, "baseline must connect eight")

                    local arena = environment:addArena()
                    assert(environment:totalConnects() == 10, "late arena adds two")
                    local folder = environment:addFolder(arena)
                    assert(environment:totalConnects() == 12, "late folder adds two")
                    local candidate = environment:addCandidate(folder, "Late", nil, 0)
                    assert(environment:totalConnects() == 13, "late candidate adds one")
                    assert(candidate.LocalTransparencyModifier == 1, "unresolved must hide")

                    folder.ChildAdded:Fire(candidate)
                    assert(
                        environment:totalConnects() == 13,
                        "duplicate child signal must not duplicate binding"
                    )
                    candidate:ServerSetAttribute("GrayboxObjectiveOwnerUserId", 101)
                    assert(candidate.LocalTransparencyModifier == 0, "resolved owner must show")
                    assert(
                        lastRender(environment).text:find("REACH YOUR GLOWING ZONE", 1, true) ~= nil,
                        "late owner metadata must update instruction"
                    )
                end)
            end,
        },
        {
            name = "DHC-07 removes stale candidate bindings before replacement",
            run = function()
                withEnvironment(function(environment: any)
                    local arena = environment:addArena()
                    local folder = environment:addFolder(arena)
                    local old = environment:addCandidate(folder, "Old", 101, 0.25)
                    local oldSignal = old:GetAttributeChangedSignal("GrayboxObjectiveOwnerUserId")
                    environment:setActiveAttributes(1, 110)
                    environment:start()
                    folder:RemoveChild(old)
                    assert(
                        old.LocalTransparencyModifier == 0.25,
                        "removed candidate must restore original transparency"
                    )

                    local replacement = environment:addCandidate(folder, "Replacement", 101, 0.4)
                    assert(
                        replacement.LocalTransparencyModifier == 0,
                        "replacement owner must show"
                    )
                    local rendersBefore = #environment.renders
                    oldSignal:FireRetained()
                    assert(
                        #environment.renders == rendersBefore,
                        "retained old callback must be inert"
                    )
                    assert(
                        replacement.LocalTransparencyModifier == 0,
                        "old callback must not alter replacement"
                    )
                end)
            end,
        },
        {
            name = "DHC-08 preserves binding across in-place objective movement",
            run = function()
                withEnvironment(function(environment: any)
                    local arena = environment:addArena()
                    local folder = environment:addFolder(arena)
                    local candidate = environment:addCandidate(folder, "Owned", 101, 0)
                    environment:setActiveAttributes(1, 110)
                    environment:start()
                    local connects = environment:totalConnects()

                    candidate.Position = { x = 30, y = 0.75, z = 30 }
                    candidate:ServerSetAttribute("GrayboxObjectiveSlot", 8)
                    environment.renderStepped:Fire()
                    assert(
                        environment:totalConnects() == connects,
                        "movement and slot metadata must not rebind"
                    )
                    assert(candidate.LocalTransparencyModifier == 0, "owner must remain visible")
                    assert(environment.viewCreateCount == 1, "movement must not create UI")
                end)
            end,
        },
        {
            name = "DHC-09 fails closed for zero or multiple owner matches",
            run = function()
                withEnvironment(function(environment: any)
                    local arena = environment:addArena()
                    local folder = environment:addFolder(arena)
                    local first = environment:addCandidate(folder, "First", 101, 0)
                    local second = environment:addCandidate(folder, "Second", 101, 0)
                    environment:setActiveAttributes(1, 110)
                    environment:start()

                    assert(first.LocalTransparencyModifier == 1, "ambiguous first must hide")
                    assert(second.LocalTransparencyModifier == 1, "ambiguous second must hide")
                    assert(
                        lastRender(environment).text:find("OBJECTIVE SYNCING...", 1, true) ~= nil,
                        "multiple matches must sync"
                    )

                    second:ServerSetAttribute("GrayboxObjectiveOwnerUserId", 202)
                    assert(first.LocalTransparencyModifier == 0, "single match must show")
                    assert(second.LocalTransparencyModifier == 1, "foreign must remain hidden")
                    folder:RemoveChild(first)
                    assert(second.LocalTransparencyModifier == 1, "zero matches must hide all")
                    assert(
                        lastRender(environment).text:find("OBJECTIVE SYNCING...", 1, true) ~= nil,
                        "zero matches must sync"
                    )
                end)
            end,
        },
        {
            name = "DHC-10 owns no Character or movement lifecycle",
            run = function()
                withEnvironment(function(environment: any)
                    environment:setActiveAttributes(1, 110)
                    environment.localPlayer.Character = { name = "First" }
                    environment:start()
                    local connects = environment:totalConnects()
                    local renders = #environment.renders

                    environment.localPlayer.Character = nil
                    environment.localPlayer.Character = { name = "Replacement" }
                    assert(
                        environment:totalConnects() == connects,
                        "Character replacement must not connect signals"
                    )
                    assert(
                        #environment.renders == renders,
                        "Character replacement must not create feedback"
                    )
                    assert(environment.viewCreateCount == 1, "Character must not duplicate UI")
                end)
            end,
        },
        {
            name = "DHC-11 stop cleans every listener view and transparency override",
            run = function()
                withEnvironment(function(environment: any)
                    local arena = environment:addArena()
                    local folder = environment:addFolder(arena)
                    local owned = environment:addCandidate(folder, "Owned", 101, 0.2)
                    local foreign = environment:addCandidate(folder, "Foreign", 202, 0.3)
                    environment:setActiveAttributes(1, 110)
                    local controller = environment:start()
                    local connects = environment:totalConnects()
                    controller.stop()

                    assert(environment:totalActiveConnections() == 0, "all listeners must stop")
                    assert(
                        environment:totalDisconnects() == connects,
                        "every connection must disconnect once"
                    )
                    assert(owned.LocalTransparencyModifier == 0.2, "owned value must restore")
                    assert(foreign.LocalTransparencyModifier == 0.3, "foreign value must restore")
                    assert(environment.viewDestroyCount == 1, "owned view must be destroyed")
                    controller.stop()
                    assert(environment.viewDestroyCount == 1, "repeated stop must be idempotent")
                end)
            end,
        },
        {
            name = "DHC-12 retained callbacks are inert and restart is clean",
            run = function()
                withEnvironment(function(environment: any)
                    local arena = environment:addArena()
                    local folder = environment:addFolder(arena)
                    environment:addCandidate(folder, "Owned", 101, 0.2)
                    environment:setActiveAttributes(1, 110)
                    local first = environment:start()
                    environment.localPlayer:ServerSetAttribute("GrayboxPhaseEndsAt", 109)
                    local rendersBeforeStop = #environment.renders
                    local originalSignals = {}
                    for _, signal in environment.signals do
                        table.insert(originalSignals, signal)
                    end
                    first.stop()

                    for _, signal in originalSignals do
                        signal:FireRetained()
                    end
                    environment:flushDeferred()
                    assert(
                        #environment.renders == rendersBeforeStop,
                        "retained callbacks must not render after stop"
                    )

                    local second = environment:start()
                    assert(second ~= first, "restart must create a fresh controller")
                    assert(environment.viewCreateCount == 2, "restart must create one fresh view")
                end)
            end,
        },
        {
            name = "DHC-13 isolates owner classification per simulated client",
            run = function()
                local function observe(localUserId: number): (number, number, string)
                    local ownedTransparency = -1
                    local foreignTransparency = -1
                    local text = ""
                    withEnvironment(function(environment: any)
                        environment.localPlayer.UserId = localUserId
                        local arena = environment:addArena()
                        local folder = environment:addFolder(arena)
                        local first = environment:addCandidate(folder, "P1", 101, 0)
                        local second = environment:addCandidate(folder, "P2", 202, 0)
                        environment:setActiveAttributes(1, 110)
                        environment:start()
                        if localUserId == 101 then
                            ownedTransparency = first.LocalTransparencyModifier
                            foreignTransparency = second.LocalTransparencyModifier
                        else
                            ownedTransparency = second.LocalTransparencyModifier
                            foreignTransparency = first.LocalTransparencyModifier
                        end
                        text = lastRender(environment).text
                    end)
                    return ownedTransparency, foreignTransparency, text
                end

                local p1Owned, p1Foreign, p1Text = observe(101)
                local p2Owned, p2Foreign, p2Text = observe(202)
                assert(p1Owned == 0 and p2Owned == 0, "each owner must see own objective")
                assert(p1Foreign == 1 and p2Foreign == 1, "each owner must hide foreign objective")
                assert(
                    p1Text:find("REACH YOUR GLOWING ZONE", 1, true) ~= nil
                        and p2Text:find("REACH YOUR GLOWING ZONE", 1, true) ~= nil,
                    "each client must compute readiness independently"
                )
            end,
        },
        {
            name = "DHC-14 exposes no outcome attribute remote or input authority",
            run = function()
                withEnvironment(function(environment: any)
                    local originalCharacter = { name = "Original" }
                    environment.localPlayer.Character = originalCharacter
                    environment:setActiveAttributes(1, 110)
                    environment:start()
                    environment.renderStepped:Fire()

                    assert(
                        environment.localPlayer.unauthorizedAttributeWrites == 0,
                        "controller must never write replicated attributes"
                    )
                    assert(
                        environment.localPlayer.Character == originalCharacter,
                        "controller must not replace Character"
                    )
                    assert(environment.viewCreateCount == 1, "only presentation is created")
                end)
            end,
        },
        {
            name = "reports UI construction failure once without partial listeners",
            run = function()
                withEnvironment(function(environment: any)
                    environment.failViewCreation = true
                    local first = environment:start()
                    local second = environment:start()
                    assert(first == second, "failed bootstrap must be guarded")
                    assert(environment.viewCreateCount == 1, "failure must not retry automatically")
                    assert(#environment.warnings == 1, "failure must report once")
                    assert(environment:totalConnects() == 0, "failure must create no listeners")
                    first.stop()
                end)
            end,
        },
    },
}
