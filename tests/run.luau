--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")

type TestCase = {
    name: string,
    run: () -> (),
}

type TestSuite = {
    suite: string,
    cases: { TestCase },
}

local function collectSpecs(directory: string, relativeDirectory: string, output: { string })
    local entries = fs.readDir(directory)
    table.sort(entries)

    for _, entry in entries do
        local absolutePath = `{directory}/{entry}`
        local relativePath = if relativeDirectory == ""
            then entry
            else `{relativeDirectory}/{entry}`

        if fs.isDir(absolutePath) then
            collectSpecs(absolutePath, relativePath, output)
        elseif entry:match("%.spec%.luau$") then
            table.insert(output, relativePath)
        end
    end
end

local specPaths = {}
collectSpecs("tests", "", specPaths)
table.sort(specPaths)

if #specPaths == 0 then
    print("[FAIL] No test specifications were found under tests/.")
    process.exit(1)
end

local passed = 0
local failed = 0

for _, specPath in specPaths do
    local modulePath = specPath:gsub("%.luau$", "")
    local loaded, suiteOrError = pcall(require, `./{modulePath}`)
    if not loaded then
        failed += 1
        print(`[FAIL] {specPath}: {tostring(suiteOrError)}`)
        continue
    end

    local suite = suiteOrError :: TestSuite
    if type(suite) ~= "table" or type(suite.suite) ~= "string" or type(suite.cases) ~= "table" then
        failed += 1
        print(`[FAIL] {specPath}: spec must return a suite name and cases array`)
        continue
    end

    for _, testCase in suite.cases do
        if
            type(testCase) ~= "table"
            or type(testCase.name) ~= "string"
            or type(testCase.run) ~= "function"
        then
            failed += 1
            print(`[FAIL] {suite.suite}: invalid test case shape`)
            continue
        end

        local succeeded, message = pcall(testCase.run)
        if succeeded then
            passed += 1
            print(`[PASS] {suite.suite} > {testCase.name}`)
        else
            failed += 1
            print(`[FAIL] {suite.suite} > {testCase.name}: {tostring(message)}`)
        end
    end
end

print(`Tests: {passed} passed, {failed} failed`)
if failed > 0 then
    process.exit(1)
end
