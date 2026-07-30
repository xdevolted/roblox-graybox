--!strict

type ViewModel = {
    phase: "PREPARING" | "ACTIVE" | "RESULT" | "RESETTING",
    generation: number?,
    tone: "NEUTRAL" | "ACTIVE" | "SUCCESS" | "FAILURE",
    text: string,
    remainingSeconds: number?,
}

type View = {
    render: (viewModel: ViewModel) -> (),
    destroy: () -> (),
}

type Present = (snapshot: any, currentTime: any, objectiveReady: any) -> ViewModel
type Controller = {
    stop: () -> (),
}

local DebugHudController = {}

local ATTRIBUTE_NAMES = {
    "GrayboxRoundPhase",
    "GrayboxRoundGeneration",
    "GrayboxRoundResult",
    "GrayboxRoundFailureReason",
    "GrayboxPhaseEndsAt",
}

local activeController: Controller? = nil

export type Dependencies = {
    localPlayer: any?,
    playerGui: any?,
    workspace: any?,
    renderStepped: any?,
    now: (() -> number)?,
    present: Present?,
    createView: ((playerGui: any) -> View)?,
    defer: ((() -> ()) -> ())?,
    isBasePart: ((value: any) -> boolean)?,
    reportWarning: ((message: string) -> ())?,
}

local function defaultPresent(snapshot: any, currentTime: any, objectiveReady: any): ViewModel
    local model = require(script.Parent.PrimitiveFeedbackModel)
    return model.present(snapshot, currentTime, objectiveReady)
end

local function defaultCreateView(playerGui: any): View
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GrayboxDebugHud"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = false
    screenGui.DisplayOrder = 10

    local label = Instance.new("TextLabel")
    label.Name = "RoundStatus"
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.fromScale(0.5, 0.03)
    label.Size = UDim2.fromOffset(520, 112)
    label.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    label.BackgroundTransparency = 0.2
    label.BorderSizePixel = 0
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 24
    label.TextWrapped = true
    label.Text = "PREPARING ROUND..."
    label.Parent = screenGui

    screenGui.Parent = playerGui

    local function render(viewModel: ViewModel)
        label.Text = viewModel.text
        if viewModel.tone == "SUCCESS" then
            label.TextColor3 = Color3.fromRGB(100, 255, 120)
        elseif viewModel.tone == "FAILURE" then
            label.TextColor3 = Color3.fromRGB(255, 110, 110)
        elseif viewModel.tone == "ACTIVE" then
            label.TextColor3 = Color3.fromRGB(255, 240, 120)
        else
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end

    local function destroy()
        screenGui:Destroy()
    end

    return table.freeze({
        render = render,
        destroy = destroy,
    })
end

local function defaultIsBasePart(value: any): boolean
    return typeof(value) == "Instance" and value:IsA("BasePart")
end

local function defaultReportWarning(message: string)
    warn(`[RobloxGraybox] {message}`)
end

local function disconnect(connection: any?)
    if connection ~= nil then
        connection:Disconnect()
    end
end

local function getChildren(parent: any): { any }
    return parent:GetChildren()
end

local function findNamedChild(parent: any, name: string): any?
    for _, child in getChildren(parent) do
        if child.Name == name then
            return child
        end
    end
    return nil
end

local function isFiniteInteger(value: any): boolean
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and value % 1 == 0
end

function DebugHudController.start(dependencies: Dependencies?): Controller
    if activeController ~= nil then
        return activeController
    end

    local provided: Dependencies = dependencies or {}
    local players = if provided.localPlayer == nil then game:GetService("Players") else nil
    local localPlayer = provided.localPlayer or players.LocalPlayer
    local playerGui = provided.playerGui or localPlayer:WaitForChild("PlayerGui")
    local workspace = provided.workspace or game:GetService("Workspace")
    local renderStepped = provided.renderStepped or game:GetService("RunService").RenderStepped
    local now: () -> number = provided.now
        or function()
            return workspace:GetServerTimeNow()
        end
    local present = provided.present or defaultPresent
    local createView = provided.createView or defaultCreateView
    local defer: (callback: () -> ()) -> () = provided.defer or task.defer
    local isBasePart = provided.isBasePart or defaultIsBasePart
    local reportWarning = provided.reportWarning or defaultReportWarning

    local created, viewOrError = pcall(createView, playerGui)
    if not created then
        reportWarning(`primitive feedback UI creation failed: {tostring(viewOrError)}`)
        local failedController: Controller
        local function stopFailed()
            if activeController == failedController then
                activeController = nil
            end
        end
        failedController = table.freeze({
            stop = stopFailed,
        })
        activeController = failedController
        return failedController
    end
    local view = viewOrError :: View

    local active = true
    local pendingRefresh = false
    local objectiveReady = false
    local baseConnections: { any } = {}
    local arenaConnections: { any } = {}
    local folderConnections: { any } = {}
    local arena: any? = nil
    local objectivesFolder: any? = nil
    local candidates: { [any]: any } = {}
    local controller: Controller

    local function isCurrent(): boolean
        return active and activeController == controller
    end

    local function readSnapshot(): any
        return {
            phase = localPlayer:GetAttribute("GrayboxRoundPhase"),
            generation = localPlayer:GetAttribute("GrayboxRoundGeneration"),
            result = localPlayer:GetAttribute("GrayboxRoundResult"),
            failureReason = localPlayer:GetAttribute("GrayboxRoundFailureReason"),
            phaseEndsAt = localPlayer:GetAttribute("GrayboxPhaseEndsAt"),
        }
    end

    local function refreshPresentation()
        if not isCurrent() then
            return
        end
        view.render(present(readSnapshot(), now(), objectiveReady))
    end

    local function scheduleRefresh()
        if not isCurrent() or pendingRefresh then
            return
        end
        pendingRefresh = true
        defer(function()
            pendingRefresh = false
            if not isCurrent() then
                return
            end
            refreshPresentation()
        end)
    end

    local function setLocalTransparency(candidate: any, value: number)
        pcall(function()
            candidate.LocalTransparencyModifier = value
        end)
    end

    local function refreshObjectives()
        if not isCurrent() then
            return
        end

        local ownedCandidate: any? = nil
        local ownedCount = 0
        local localUserId = localPlayer.UserId
        for candidate in candidates do
            local ownerUserId = candidate:GetAttribute("GrayboxObjectiveOwnerUserId")
            if
                isFiniteInteger(ownerUserId)
                and isFiniteInteger(localUserId)
                and ownerUserId == localUserId
            then
                ownedCount += 1
                ownedCandidate = candidate
            end
        end

        objectiveReady = ownedCount == 1
        for candidate in candidates do
            setLocalTransparency(
                candidate,
                if objectiveReady and candidate == ownedCandidate then 0 else 1
            )
        end
        refreshPresentation()
    end

    local function unbindCandidate(candidate: any)
        local record = candidates[candidate]
        if record == nil then
            return
        end
        candidates[candidate] = nil
        record.active = false
        disconnect(record.ownerConnection)
        setLocalTransparency(candidate, record.originalTransparency)
    end

    local function bindCandidate(candidate: any)
        if not isCurrent() or not isBasePart(candidate) or candidates[candidate] ~= nil then
            return
        end

        local record = {
            active = true,
            originalTransparency = candidate.LocalTransparencyModifier,
            ownerConnection = nil,
        }
        candidates[candidate] = record
        record.ownerConnection = candidate
            :GetAttributeChangedSignal("GrayboxObjectiveOwnerUserId")
            :Connect(function()
                if not isCurrent() or not record.active or candidates[candidate] ~= record then
                    return
                end
                refreshObjectives()
            end)
        refreshObjectives()
    end

    local function clearCandidates()
        local owned = {}
        for candidate in candidates do
            table.insert(owned, candidate)
        end
        for _, candidate in owned do
            unbindCandidate(candidate)
        end
        objectiveReady = false
    end

    local bindFolder: (folder: any?) -> ()
    local bindArena: (nextArena: any?) -> ()

    bindFolder = function(folder: any?)
        if objectivesFolder == folder then
            return
        end

        for _, connection in folderConnections do
            disconnect(connection)
        end
        table.clear(folderConnections)
        clearCandidates()
        objectivesFolder = folder

        if folder == nil or not isCurrent() then
            refreshPresentation()
            return
        end

        table.insert(
            folderConnections,
            folder.ChildAdded:Connect(function(child: any)
                if isCurrent() and objectivesFolder == folder then
                    bindCandidate(child)
                end
            end)
        )
        table.insert(
            folderConnections,
            folder.ChildRemoved:Connect(function(child: any)
                if not isCurrent() or objectivesFolder ~= folder then
                    return
                end
                unbindCandidate(child)
                refreshObjectives()
            end)
        )

        for _, child in getChildren(folder) do
            bindCandidate(child)
        end
        refreshObjectives()
    end

    bindArena = function(nextArena: any?)
        if arena == nextArena then
            return
        end

        bindFolder(nil)
        for _, connection in arenaConnections do
            disconnect(connection)
        end
        table.clear(arenaConnections)
        arena = nextArena

        if nextArena == nil or not isCurrent() then
            refreshPresentation()
            return
        end

        table.insert(
            arenaConnections,
            nextArena.ChildAdded:Connect(function(child: any)
                if
                    isCurrent()
                    and arena == nextArena
                    and child.Name == "Objectives"
                    and objectivesFolder == nil
                then
                    bindFolder(child)
                end
            end)
        )
        table.insert(
            arenaConnections,
            nextArena.ChildRemoved:Connect(function(child: any)
                if not isCurrent() or arena ~= nextArena or child ~= objectivesFolder then
                    return
                end
                bindFolder(nil)
                bindFolder(findNamedChild(nextArena, "Objectives"))
            end)
        )
        bindFolder(findNamedChild(nextArena, "Objectives"))
    end

    local function stop()
        if not active then
            return
        end
        active = false
        pendingRefresh = false

        for _, connection in baseConnections do
            disconnect(connection)
        end
        table.clear(baseConnections)
        bindArena(nil)
        view.destroy()

        if activeController == controller then
            activeController = nil
        end
    end

    controller = table.freeze({
        stop = stop,
    })
    activeController = controller

    for _, attributeName in ATTRIBUTE_NAMES do
        table.insert(
            baseConnections,
            localPlayer:GetAttributeChangedSignal(attributeName):Connect(scheduleRefresh)
        )
    end
    table.insert(baseConnections, renderStepped:Connect(refreshPresentation))
    table.insert(
        baseConnections,
        workspace.ChildAdded:Connect(function(child: any)
            if isCurrent() and child.Name == "GrayboxArena" and arena == nil then
                bindArena(child)
            end
        end)
    )
    table.insert(
        baseConnections,
        workspace.ChildRemoved:Connect(function(child: any)
            if not isCurrent() or child ~= arena then
                return
            end
            bindArena(nil)
            bindArena(findNamedChild(workspace, "GrayboxArena"))
        end)
    )

    bindArena(findNamedChild(workspace, "GrayboxArena"))
    refreshPresentation()
    return controller
end

return table.freeze(DebugHudController)
