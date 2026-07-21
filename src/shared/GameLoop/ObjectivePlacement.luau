--!strict

local ObjectivePlacement = {}

export type Assignment = {
    slotId: number,
    x: number,
    z: number,
}

export type Rejection =
    "INVALID_PREFERENCE"
    | "DUPLICATE_PLAYER"
    | "NO_AVAILABLE_SLOT"
    | "DESTROYED"

export type Registry = {
    assign: (playerKey: any, preferredIndex: any) -> (Assignment?, Rejection?),
    get: (playerKey: any) -> Assignment?,
    remove: (playerKey: any) -> boolean,
    destroy: () -> (),
}

local slots: { Assignment } = {
    table.freeze({ slotId = 1, x = -30, z = -30 }),
    table.freeze({ slotId = 2, x = 0, z = -30 }),
    table.freeze({ slotId = 3, x = 30, z = -30 }),
    table.freeze({ slotId = 4, x = -30, z = 0 }),
    table.freeze({ slotId = 5, x = 30, z = 0 }),
    table.freeze({ slotId = 6, x = -30, z = 30 }),
    table.freeze({ slotId = 7, x = 0, z = 30 }),
    table.freeze({ slotId = 8, x = 30, z = 30 }),
}
table.freeze(slots)

local function isValidPreference(value: any): boolean
    return type(value) == "number" and value % 1 == 0 and value >= 1 and value <= #slots
end

function ObjectivePlacement.new(): Registry
    local assignments: { [any]: Assignment } = {}
    local occupiedSlots: { [number]: any } = {}
    local destroyed = false

    local function assign(playerKey: any, preferredIndex: any): (Assignment?, Rejection?)
        if destroyed then
            return nil, "DESTROYED"
        end
        if not isValidPreference(preferredIndex) then
            return nil, "INVALID_PREFERENCE"
        end
        if assignments[playerKey] ~= nil then
            return nil, "DUPLICATE_PLAYER"
        end

        for offset = 0, #slots - 1 do
            local index = ((preferredIndex - 1 + offset) % #slots) + 1
            if occupiedSlots[index] == nil then
                local slot = slots[index]
                local assignment: Assignment = table.freeze({
                    slotId = slot.slotId,
                    x = slot.x,
                    z = slot.z,
                })
                assignments[playerKey] = assignment
                occupiedSlots[index] = playerKey
                return assignment, nil
            end
        end

        return nil, "NO_AVAILABLE_SLOT"
    end

    local function get(playerKey: any): Assignment?
        if destroyed then
            return nil
        end
        return assignments[playerKey]
    end

    local function remove(playerKey: any): boolean
        if destroyed then
            return false
        end

        local assignment = assignments[playerKey]
        if assignment == nil then
            return false
        end

        assignments[playerKey] = nil
        occupiedSlots[assignment.slotId] = nil
        return true
    end

    local function destroy()
        if destroyed then
            return
        end
        destroyed = true
        table.clear(assignments)
        table.clear(occupiedSlots)
    end

    return table.freeze({
        assign = assign,
        get = get,
        remove = remove,
        destroy = destroy,
    }) :: Registry
end

return table.freeze(ObjectivePlacement)
