--!strict

type RainLayer = {
    setPosition: (position: any) -> (),
    destroy: () -> (),
}

type RainSound = {
    destroy: () -> (),
}

type Controller = {
    stop: () -> (),
}

type LayerFactory = (world: any, layerIndex: number) -> RainLayer
type SoundFactory = (soundParent: any) -> RainSound
type TargetPositionReader = (world: any) -> any?
type PositionValidator = (position: any) -> boolean

local RainController = {}

local LAYER_COUNT = 2
local SOUND_ID = "rbxassetid://1516791621"
local LAYER_OFFSET_SPECS = {
    { x = -10, y = 0, z = -8 },
    { x = 10, y = 6, z = 8 },
}

local activeController: Controller? = nil

export type Dependencies = {
    world: any?,
    soundParent: any?,
    renderStepped: any?,
    createLayer: LayerFactory?,
    createSound: SoundFactory?,
    readTargetPosition: TargetPositionReader?,
    isFinitePosition: PositionValidator?,
    reportWarning: ((message: string) -> ())?,
}

local function defaultCreateLayer(world: any, layerIndex: number): RainLayer
    local offsetSpec = assert(LAYER_OFFSET_SPECS[layerIndex], "rain layer index is out of range")
    local offset = Vector3.new(offsetSpec.x, offsetSpec.y, offsetSpec.z)

    local volume = Instance.new("Part")
    volume.Name = `GrayboxRainVolume{layerIndex}`
    volume.Size = Vector3.new(64, 1, 64)
    volume.Anchored = true
    volume.Transparency = 1
    volume.CanCollide = false
    volume.CanTouch = false
    volume.CanQuery = false
    volume.CastShadow = false

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = `GrayboxRainEmitter{layerIndex}`
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Shape = Enum.ParticleEmitterShape.Box
    emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
    emitter.EmissionDirection = Enum.NormalId.Bottom
    emitter.SpreadAngle = Vector2.new(5, 5)
    emitter.Rate = 400
    emitter.Speed = NumberRange.new(0)
    emitter.Acceleration = Vector3.new(0, -110, 0)
    emitter.Lifetime = NumberRange.new(0.9, 1.1)
    emitter.Size = NumberSequence.new(0.28)
    emitter.Squash = NumberSequence.new(4)
    emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
    emitter.Color = ColorSequence.new(Color3.fromRGB(190, 220, 255))
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 0.55),
    })
    emitter.LightInfluence = 0
    emitter.LightEmission = 0.65
    emitter.Enabled = true
    emitter.Parent = volume
    volume.Parent = world

    local destroyed = false

    local function setPosition(position: any)
        if destroyed then
            return
        end
        volume.Position = position + offset
    end

    local function destroy()
        if destroyed then
            return
        end
        destroyed = true
        volume:Destroy()
    end

    return table.freeze({
        setPosition = setPosition,
        destroy = destroy,
    })
end

local function defaultCreateSound(soundParent: any): RainSound
    local sound = Instance.new("Sound")
    local configuredAndPlayed, soundError = pcall(function()
        sound.Name = "GrayboxRainAmbience"
        sound.SoundId = SOUND_ID
        sound.Looped = true
        sound.Volume = 0.35
        sound.Parent = soundParent
        sound:Play()
    end)
    if not configuredAndPlayed then
        sound:Destroy()
        error(soundError)
    end

    local destroyed = false

    local function destroy()
        if destroyed then
            return
        end
        destroyed = true
        sound:Stop()
        sound:Destroy()
    end

    return table.freeze({
        destroy = destroy,
    })
end

local function defaultReadTargetPosition(world: any): Vector3?
    local camera = world.CurrentCamera
    if camera == nil then
        return nil
    end
    return camera.CFrame.Position + Vector3.new(0, 28, 0)
end

local function isFiniteNumber(value: number): boolean
    return value == value and value ~= math.huge and value ~= -math.huge
end

local function defaultIsFinitePosition(position: any): boolean
    return typeof(position) == "Vector3"
        and isFiniteNumber(position.X)
        and isFiniteNumber(position.Y)
        and isFiniteNumber(position.Z)
end

local function defaultReportWarning(message: string)
    warn(`[RobloxGraybox] {message}`)
end

local function disconnect(connection: any?)
    if connection ~= nil then
        connection:Disconnect()
    end
end

local function makeFailedController(): Controller
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

function RainController.start(dependencies: Dependencies?): Controller
    if activeController ~= nil then
        return activeController
    end

    local provided: Dependencies = dependencies or {}
    local world = provided.world or game:GetService("Workspace")
    local soundParent = provided.soundParent or game:GetService("SoundService")
    local renderStepped = provided.renderStepped or game:GetService("RunService").RenderStepped
    local createLayer = provided.createLayer or defaultCreateLayer
    local createSound = provided.createSound or defaultCreateSound
    local readTargetPosition = provided.readTargetPosition or defaultReadTargetPosition
    local isFinitePosition = provided.isFinitePosition or defaultIsFinitePosition
    local reportWarning = provided.reportWarning or defaultReportWarning

    local layers: { RainLayer } = {}
    for layerIndex = 1, LAYER_COUNT do
        local created, layerOrError = pcall(createLayer, world, layerIndex)
        if not created then
            for _, layer in layers do
                layer.destroy()
            end
            reportWarning(`rain layer {layerIndex} creation failed: {tostring(layerOrError)}`)
            return makeFailedController()
        end
        table.insert(layers, layerOrError :: RainLayer)
    end

    local sound: RainSound? = nil
    local soundCreated, soundOrError = pcall(createSound, soundParent)
    if soundCreated then
        sound = soundOrError :: RainSound
    else
        reportWarning(`rain ambience creation failed: {tostring(soundOrError)}`)
    end

    local active = true
    local renderConnection: any? = nil
    local controller: Controller

    local function isCurrent(): boolean
        return active and activeController == controller
    end

    local function update()
        if not isCurrent() then
            return
        end

        local readSucceeded, targetPosition = pcall(readTargetPosition, world)
        if not readSucceeded or not isFinitePosition(targetPosition) then
            return
        end
        for _, layer in layers do
            layer.setPosition(targetPosition)
        end
    end

    local function stop()
        if not active then
            return
        end
        active = false
        disconnect(renderConnection)
        renderConnection = nil
        if sound ~= nil then
            sound.destroy()
            sound = nil
        end
        for _, layer in layers do
            layer.destroy()
        end
        table.clear(layers)

        if activeController == controller then
            activeController = nil
        end
    end

    controller = table.freeze({
        stop = stop,
    })
    activeController = controller
    renderConnection = renderStepped:Connect(update)
    update()
    return controller
end

return table.freeze(RainController)
