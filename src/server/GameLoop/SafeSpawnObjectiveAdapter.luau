--!strict

type Assignment = {
    slotId: number,
    x: number,
    z: number,
}

type PlacementRejection =
    "INVALID_PREFERENCE"
    | "DUPLICATE_PLAYER"
    | "UNKNOWN_PLAYER"
    | "NO_AVAILABLE_SLOT"
    | "DESTROYED"

type PlacementRegistry = {
    assign: (player: any, preferredIndex: any) -> (Assignment?, PlacementRejection?),
    reassign: (player: any, preferredIndex: any) -> (Assignment?, PlacementRejection?),
    get: (player: any) -> Assignment?,
    remove: (player: any) -> boolean,
    destroy: () -> (),
}

type PlacementRegistryModule = {
    new: () -> PlacementRegistry,
}

type PlacementRegistryFactory = () -> PlacementRegistry

type VectorSpec = {
    x: number,
    y: number,
    z: number,
}

export type InstanceSpec = {
    className: "Folder" | "Part" | "SpawnLocation",
    name: string,
    kind: "ARENA" | "PLATFORM" | "SPAWN" | "GUARD" | "OBJECTIVES" | "OBJECTIVE",
    size: VectorSpec?,
    position: VectorSpec?,
}

type InstanceFactory = (spec: InstanceSpec, parent: any) -> any
type PreferredIndex = (player: any) -> number
type ObjectiveMover = (objective: any, assignment: Assignment) -> ()

local SafeSpawnObjectiveAdapter = {}

local function normalizePlacementRejection(rejection: string?): PlacementRejection?
    if rejection == nil then
        return nil
    end
    if rejection == "INVALID_PREFERENCE" then
        return "INVALID_PREFERENCE"
    end
    if rejection == "DUPLICATE_PLAYER" then
        return "DUPLICATE_PLAYER"
    end
    if rejection == "UNKNOWN_PLAYER" then
        return "UNKNOWN_PLAYER"
    end
    if rejection == "NO_AVAILABLE_SLOT" then
        return "NO_AVAILABLE_SLOT"
    end
    if rejection == "DESTROYED" then
        return "DESTROYED"
    end
    error(`unexpected ObjectivePlacement rejection: {rejection}`)
end

local staticGeometry: { InstanceSpec } = {
    {
        className = "Part",
        name = "Platform",
        kind = "PLATFORM",
        size = { x = 96, y = 1, z = 96 },
        position = { x = 0, y = 0, z = 0 },
    },
    {
        className = "SpawnLocation",
        name = "GuardedSpawn",
        kind = "SPAWN",
        size = { x = 16, y = 1, z = 16 },
        position = { x = 0, y = 1, z = 0 },
    },
    {
        className = "Part",
        name = "StartBackWall",
        kind = "GUARD",
        size = { x = 20, y = 4, z = 1 },
        position = { x = 0, y = 2.5, z = -10 },
    },
    {
        className = "Part",
        name = "StartLeftWall",
        kind = "GUARD",
        size = { x = 1, y = 4, z = 20 },
        position = { x = -10, y = 2.5, z = 0 },
    },
    {
        className = "Part",
        name = "StartRightWall",
        kind = "GUARD",
        size = { x = 1, y = 4, z = 20 },
        position = { x = 10, y = 2.5, z = 0 },
    },
}

export type Dependencies = {
    players: any?,
    world: any?,
    instanceFactory: InstanceFactory?,
    registryFactory: PlacementRegistryFactory?,
    preferredIndex: PreferredIndex?,
    moveObjective: ObjectiveMover?,
}

export type Controller = {
    getAssignment: (player: any) -> Assignment?,
    getObjective: (player: any) -> any?,
    repositionObjective: (player: any) -> (Assignment?, PlacementRejection?),
    stop: () -> (),
}

local function defaultRegistryFactory(): PlacementRegistry
    local placementModule: PlacementRegistryModule =
        require(game:GetService("ReplicatedStorage").Shared.GameLoop.ObjectivePlacement)
    return placementModule.new()
end

local function defaultPreferredIndex(player: any): number
    return (math.abs(player.UserId) % 8) + 1
end

local function defaultMoveObjective(objective: any, assignment: Assignment)
    objective.Name = `Objective_{assignment.slotId}`
    objective.Position = Vector3.new(assignment.x, 0.75, assignment.z)
    objective:SetAttribute("GrayboxObjectiveSlot", assignment.slotId)
end

local function defaultInstanceFactory(spec: InstanceSpec, parent: any): any
    local instance: any = Instance.new(spec.className)
    instance.Name = spec.name

    if spec.className ~= "Folder" then
        local size = assert(spec.size, "physical Instance requires size")
        local position = assert(spec.position, "physical Instance requires position")
        instance.Anchored = true
        instance.Size = Vector3.new(size.x, size.y, size.z)
        instance.Position = Vector3.new(position.x, position.y, position.z)
        instance.CanQuery = true
        instance.CanTouch = true

        if spec.kind == "OBJECTIVE" then
            instance.CanCollide = false
            instance.Material = Enum.Material.Neon
            instance.Color = Color3.fromRGB(57, 255, 20)
        else
            instance.CanCollide = true
            instance.Material = Enum.Material.SmoothPlastic
            instance.Color = Color3.fromRGB(128, 128, 128)
        end

        if spec.className == "SpawnLocation" then
            instance.Neutral = true
            instance.Enabled = true
            instance.AllowTeamChangeOnTouch = false
        end
    end

    instance.Parent = parent
    return instance
end

function SafeSpawnObjectiveAdapter.start(dependencies: Dependencies?): Controller
    local provided: Dependencies = dependencies or {}
    local players = provided.players or game:GetService("Players")
    local world = provided.world or game:GetService("Workspace")
    local instanceFactory: InstanceFactory = provided.instanceFactory or defaultInstanceFactory
    local registryFactory: PlacementRegistryFactory = provided.registryFactory
        or defaultRegistryFactory
    local preferredIndex: PreferredIndex = provided.preferredIndex or defaultPreferredIndex
    local moveObjective: ObjectiveMover = provided.moveObjective or defaultMoveObjective

    local registry = registryFactory()
    local objectives: { [any]: any } = {}
    local initializing: { [any]: boolean } = {}
    local stopped = false

    local arenaRoot = instanceFactory({
        className = "Folder",
        name = "GrayboxArena",
        kind = "ARENA",
    }, world)

    for _, spec in staticGeometry do
        instanceFactory(spec, arenaRoot)
    end

    local objectivesContainer = instanceFactory({
        className = "Folder",
        name = "Objectives",
        kind = "OBJECTIVES",
    }, arenaRoot)

    local function initializePlayer(player: any)
        if stopped or objectives[player] ~= nil or initializing[player] == true then
            return
        end

        initializing[player] = true
        local assignment = registry.assign(player, preferredIndex(player))
        if assignment == nil then
            initializing[player] = nil
            return
        end

        local objective = instanceFactory({
            className = "Part",
            name = `Objective_{assignment.slotId}`,
            kind = "OBJECTIVE",
            size = { x = 10, y = 0.5, z = 10 },
            position = { x = assignment.x, y = 0.75, z = assignment.z },
        }, objectivesContainer)
        objective:SetAttribute("GrayboxObjectiveOwnerUserId", player.UserId)
        objective:SetAttribute("GrayboxObjectiveSlot", assignment.slotId)

        objectives[player] = objective
        initializing[player] = nil
    end

    local function removePlayer(player: any)
        if stopped then
            return
        end

        local objective = objectives[player]
        objectives[player] = nil
        initializing[player] = nil
        if objective ~= nil then
            objective:Destroy()
        end
        registry.remove(player)
    end

    local connections = {
        players.PlayerAdded:Connect(initializePlayer),
        players.PlayerRemoving:Connect(removePlayer),
    }

    for _, player in players:GetPlayers() do
        initializePlayer(player)
    end

    local function getAssignment(player: any): Assignment?
        if stopped then
            return nil
        end
        return registry.get(player)
    end

    local function getObjective(player: any): any?
        if stopped then
            return nil
        end
        return objectives[player]
    end

    local function repositionObjective(player: any): (Assignment?, PlacementRejection?)
        if stopped then
            return nil, "DESTROYED"
        end

        local objective = objectives[player]
        local previous = registry.get(player)
        if objective == nil or previous == nil then
            return nil, "UNKNOWN_PLAYER"
        end

        local preferredIndexForReplay = (previous.slotId % 8) + 1
        local assignment, rejection = registry.reassign(player, preferredIndexForReplay)
        if assignment == nil then
            return nil, normalizePlacementRejection(rejection)
        end

        moveObjective(objective, assignment)
        return assignment, nil
    end

    local function stop()
        if stopped then
            return
        end
        stopped = true

        for _, connection in connections do
            connection:Disconnect()
        end

        local ownedObjectives: { any } = {}
        for _, objective in objectives do
            table.insert(ownedObjectives, objective)
        end
        table.clear(objectives)
        table.clear(initializing)

        for _, objective in ownedObjectives do
            objective:Destroy()
        end
        registry.destroy()
        arenaRoot:Destroy()
    end

    return table.freeze({
        getAssignment = getAssignment,
        getObjective = getObjective,
        repositionObjective = repositionObjective,
        stop = stop,
    }) :: Controller
end

return table.freeze(SafeSpawnObjectiveAdapter)
