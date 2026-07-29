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
    | "UNKNOWN_PLAYER"
    | "NO_AVAILABLE_SLOT"
    | "DESTROYED"

export type Registry = {
    assign: (playerKey: any, preferredIndex: any) -> (Assignment?, Rejection?),
    reassign: (playerKey: any, preferredIndex: any) -> (Assignment?, Rejection?),
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
    local occupiedSlots: { [number]: number } = {}
    local assignmentCount = 0
    local destroyed = false

    local function makeAssignment(index: number): Assignment
        local slot = slots[index]
        return table.freeze({
            slotId = slot.slotId,
            x = slot.x,
            z = slot.z,
        }) :: Assignment
    end

    local function occupy(index: number)
        occupiedSlots[index] = (occupiedSlots[index] or 0) + 1
    end

    local function release(index: number)
        local nextCount = (occupiedSlots[index] or 0) - 1
        if nextCount <= 0 then
            occupiedSlots[index] = nil
        else
            occupiedSlots[index] = nextCount
        end
    end

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
        if assignmentCount >= #slots then
            return nil, "NO_AVAILABLE_SLOT"
        end

        for offset = 0, #slots - 1 do
            local index = ((preferredIndex - 1 + offset) % #slots) + 1
            if occupiedSlots[index] == nil then
                local assignment = makeAssignment(index)
                assignments[playerKey] = assignment
                occupy(index)
                assignmentCount += 1
                return assignment, nil
            end
        end

        return nil, "NO_AVAILABLE_SLOT"
    end

    local function reassign(playerKey: any, preferredIndex: any): (Assignment?, Rejection?)
        if destroyed then
            return nil, "DESTROYED"
        end
        if not isValidPreference(preferredIndex) then
            return nil, "INVALID_PREFERENCE"
        end

        local previous = assignments[playerKey]
        if previous == nil then
            return nil, "UNKNOWN_PLAYER"
        end

        local selectedIndex: number? = nil
        for offset = 0, #slots - 1 do
            local index = ((preferredIndex - 1 + offset) % #slots) + 1
            if index ~= previous.slotId and occupiedSlots[index] == nil then
                selectedIndex = index
                break
            end
        end

        if selectedIndex == nil then
            -- At full capacity, overlap is intentional so one player's replay can
            -- move without changing another assignment. Counts keep release exact.
            for offset = 0, #slots - 1 do
                local index = ((preferredIndex - 1 + offset) % #slots) + 1
                if index ~= previous.slotId then
                    selectedIndex = index
                    break
                end
            end
        end

        local nextIndex = assert(selectedIndex, "canonical catalog requires a different slot")
        local assignment = makeAssignment(nextIndex)
        release(previous.slotId)
        occupy(nextIndex)
        assignments[playerKey] = assignment
        return assignment, nil
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
        release(assignment.slotId)
        assignmentCount -= 1
        return true
    end

    local function destroy()
        if destroyed then
            return
        end
        destroyed = true
        table.clear(assignments)
        table.clear(occupiedSlots)
        assignmentCount = 0
    end

    return table.freeze({
        assign = assign,
        reassign = reassign,
        get = get,
        remove = remove,
        destroy = destroy,
    }) :: Registry
end

return table.freeze(ObjectivePlacement)
