--!strict

local ObjectivePlacement = require("../../src/shared/GameLoop/ObjectivePlacement")

local expectedSlots = {
    { x = -30, z = -30 },
    { x = 0, z = -30 },
    { x = 30, z = -30 },
    { x = -30, z = 0 },
    { x = 30, z = 0 },
    { x = -30, z = 30 },
    { x = 0, z = 30 },
    { x = 30, z = 30 },
}

local function assign(registry: ObjectivePlacement.Registry, player: any, preferredIndex: any)
    local assignment, rejection = registry.assign(player, preferredIndex)
    assert(assignment ~= nil, `expected assignment, got {tostring(rejection)}`)
    assert(rejection == nil, "accepted assignment must not reject")
    return assignment :: ObjectivePlacement.Assignment
end

return {
    suite = "Objective placement",
    cases = {
        {
            name = "defines eight ordered valid frozen slots",
            run = function()
                local registry = ObjectivePlacement.new()
                local seen = {}
                for index, expected in expectedSlots do
                    local assignment = assign(registry, {}, index)
                    assert(assignment.slotId == index, "slot order must be canonical")
                    assert(
                        assignment.x == expected.x and assignment.z == expected.z,
                        "slot coordinates must match the plan"
                    )
                    assert(table.isfrozen(assignment), "assignments must be immutable")
                    assert(
                        seen[`{assignment.x},{assignment.z}`] == nil,
                        "slot coordinates must be unique"
                    )
                    seen[`{assignment.x},{assignment.z}`] = true
                    assert(math.abs(assignment.x) + 5 <= 48, "objective must fit platform X")
                    assert(math.abs(assignment.z) + 5 <= 48, "objective must fit platform Z")
                    assert(
                        math.abs(assignment.x) >= 15 or math.abs(assignment.z) >= 15,
                        "objective must not overlap guarded start"
                    )
                end
            end,
        },
        {
            name = "assigns the preferred free slot",
            run = function()
                local registry = ObjectivePlacement.new()
                local player = {}
                local assignment = assign(registry, player, 5)
                assert(assignment.slotId == 5, "free preference must be selected")
                assert(registry.get(player) == assignment, "stored assignment identity must match")
            end,
        },
        {
            name = "scans cyclically from an occupied preference",
            run = function()
                local registry = ObjectivePlacement.new()
                assign(registry, {}, 8)
                local wrapped = assign(registry, {}, 8)
                assert(wrapped.slotId == 1, "occupied slot eight must wrap to slot one")
            end,
        },
        {
            name = "rejects duplicate players without mutation",
            run = function()
                local registry = ObjectivePlacement.new()
                local player = {}
                local original = assign(registry, player, 2)
                local duplicate, rejection = registry.assign(player, 7)
                assert(
                    duplicate == nil and rejection == "DUPLICATE_PLAYER",
                    "duplicate must reject"
                )
                assert(
                    registry.get(player) == original,
                    "duplicate must preserve original identity"
                )
                assert(
                    assign(registry, {}, 2).slotId == 3,
                    "duplicate must not consume another slot"
                )
            end,
        },
        {
            name = "rejects invalid preferences without mutation",
            run = function()
                local registry = ObjectivePlacement.new()
                local player = {}
                local invalidCases = {
                    { value = nil },
                    { value = 0 },
                    { value = 9 },
                    { value = 1.5 },
                    { value = "1" },
                }
                for _, case in invalidCases do
                    local assignment, rejection = registry.assign(player, case.value)
                    assert(
                        assignment == nil and rejection == "INVALID_PREFERENCE",
                        "invalid preference must reject"
                    )
                    assert(registry.get(player) == nil, "invalid preference must not assign")
                end
                assert(
                    assign(registry, player, 1).slotId == 1,
                    "invalid inputs must not consume slots"
                )
            end,
        },
        {
            name = "keeps first through eighth assignments distinct",
            run = function()
                local registry = ObjectivePlacement.new()
                local assignments = {}
                for index = 1, 8 do
                    local player = {}
                    local assignment = assign(registry, player, 1)
                    assert(assignment.slotId == index, "fixed scan must fill slots in order")
                    for _, existing in assignments do
                        assert(existing ~= assignment, "assignment identities must not alias")
                        assert(
                            existing.slotId ~= assignment.slotId,
                            "slot ownership must be unique"
                        )
                    end
                    table.insert(assignments, assignment)
                end
            end,
        },
        {
            name = "rejects a ninth player without changing the first eight",
            run = function()
                local registry = ObjectivePlacement.new()
                local players = {}
                local assignments = {}
                for _ = 1, 8 do
                    local player = {}
                    table.insert(players, player)
                    table.insert(assignments, assign(registry, player, 1))
                end

                local overflow = {}
                local assignment, rejection = registry.assign(overflow, 1)
                assert(
                    assignment == nil and rejection == "NO_AVAILABLE_SLOT",
                    "ninth player must reject"
                )
                assert(registry.get(overflow) == nil, "overflow player must remain unassigned")
                for index, player in players do
                    assert(
                        registry.get(player) == assignments[index],
                        "overflow must preserve every assignment identity"
                    )
                end
            end,
        },
        {
            name = "removes one player and deterministically reuses only the freed slot",
            run = function()
                local registry = ObjectivePlacement.new()
                local first = {}
                local second = {}
                assign(registry, first, 1)
                local secondAssignment = assign(registry, second, 1)
                assert(registry.remove(first), "first removal must succeed")
                assert(not registry.remove(first), "repeated removal must be a no-op")
                assert(
                    registry.get(second) == secondAssignment,
                    "other assignment must remain unchanged"
                )
                local replacement = assign(registry, {}, 1)
                assert(replacement.slotId == 1, "released preferred slot must be reused")
                assert(
                    registry.get(second) == secondAssignment,
                    "reuse must not reassign another player"
                )
            end,
        },
        {
            name = "destroys idempotently and rejects later assignment",
            run = function()
                local registry = ObjectivePlacement.new()
                local player = {}
                assign(registry, player, 1)
                registry.destroy()
                registry.destroy()
                assert(registry.get(player) == nil, "destroy must clear assignments")
                assert(not registry.remove(player), "destroyed registry must reject removal")
                local assignment, rejection = registry.assign({}, 1)
                assert(
                    assignment == nil and rejection == "DESTROYED",
                    "destroyed registry must reject assignment"
                )
            end,
        },
    },
}
