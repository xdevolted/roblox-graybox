--!strict

local DebugHudController = require("../src/client/Prototype/DebugHudController")
local InputController = require("../src/client/Prototype/InputController")

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
    },
}
