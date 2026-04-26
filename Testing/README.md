# EllesmereUI Testing

This directory contains the standalone Lua test setup for EllesmereUI.
It is the single home for test infrastructure, test specs, and generated local
test artifacts.

The layout is intentionally split by responsibility so the suite can grow
without turning into one large bootstrap file and one large spec file.

## Structure

- `Containerfile` - reusable container image for Lua 5.1 and `busted`
- `.busted` - central `busted` configuration for helper loading and discovery
- `Support/bootstrap.lua` - WoW API bootstrap for loading `EllesmereUI.lua`
- `Tests/Core/` - pure core helper specs grouped by concern
- `Tests/Modules/` - future module-specific specs for addon subfolders
- `run-tests.ps1` - local PowerShell wrapper around Podman test execution
- `TestResults/` - generated local test artifacts such as `busted.log`, `junit.xml`, and coverage reports

The intended split is:

- `Testing/Support` contains only shared bootstrap and future shared helpers.
- `Testing/Tests/Core` contains pure helper/unit specs for `EllesmereUI.lua`, grouped by subject such as fonts, colors, themes, and reset logic.
- `Testing/Tests/Modules` is reserved for specs that target individual addon modules.
- `Testing/TestResults` contains only generated artifacts.
- `Testing/Containerfile`, `Testing/.busted`, and `Testing/run-tests.ps1` define how tests are executed locally and in CI.

## Local Run

Use the shared GHCR image by default. This is the normal local workflow and matches CI behavior:

```powershell
.\Testing\run-tests.ps1
```

If you are changing the container definition itself, rebuild locally:

```powershell
.\Testing\run-tests.ps1 -Build -ImageName ellesmereui-tests:latest
```

If your GHCR package is private, log in first:

```powershell
podman login ghcr.io
```

For focused work on a single spec, run only that file:

```powershell
.\Testing\run-tests.ps1 -Build -ImageName ellesmereui-tests:latest -Path Testing/Tests/Modules/CooldownManager/spell_picker_spec.lua
```

This is the preferred workflow while adding coverage or isolating a bug. Run the
smallest relevant spec first, then widen back out only after the local slice is
understood.

## Writing Tests

Tests in this repository are meant to find addon bugs, not just keep the suite
green. New specs should follow the same basic rules.

### Placement

- Put shared bootstrap and helpers in `Testing/Support/` only.
- Put `EllesmereUI.lua` helper coverage in `Testing/Tests/Core/`.
- Put module-specific coverage in `Testing/Tests/Modules/<AddonFolder>/`.
- Prefer one focused spec per production file or tightly related helper group.

### Structure

- Load only the target file under test with `loadfile(...)` when possible.
- Build a minimal `ns` table for the target file instead of loading unrelated modules.
- Keep WoW globals and addon globals stubbed inside `before_each` and restore them in `after_each`.
- Stub only the APIs needed for the behavior being tested. Do not build a fake full WoW client unless the test actually needs it.
- Prefer small local helper functions inside the spec for repeated setup, such as `buildNamespace`, `makeActivePool`, or value-formatting helpers.

### Assertions

- Write behavior-first test names that describe the user-visible or data-visible contract.
- Add explicit assertion messages when the failure would otherwise be ambiguous.
- Prefer checking the concrete state transition or returned value that matters, not incidental implementation details.
- If a test fails because the harness is wrong, fix the harness first. A nil stub error is not a useful product signal.

### Bug-Finding Rules

- It is acceptable for a new test to stay red if it exposes a real addon bug.
- Keep intentional bug-revealing tests in the suite when they describe the correct behavior clearly.
- Do not weaken assertions just to make CI green.
- Distinguish clearly between a harness failure, an intentionally red bug test, and a passing regression test.

### Coverage Strategy

- Use `Testing/TestResults/luacov.report.out` to decide what to test next.
- Treat coverage as a search tool, not as the goal by itself.
- Prefer uncovered branches with clear behavior over chasing lines that only reflect defensive guards or bootstrap noise.
- Stop when remaining gaps are mostly artificial, environment-bound, or already represented by intentionally red bug tests.

### Preferred Workflow

1. Pick one concrete production file.
2. Add a small number of tests for the most local decision-making helpers first.
3. Run the focused spec.
4. Fix test harness problems immediately.
5. Keep real bug failures visible.
6. Use coverage output to choose the next meaningful branch.

### Minimal Pattern

Most module specs should roughly follow this shape:

```lua
describe("module behavior", function()
	local modulePath = "SomeFolder/SomeFile.lua"
	local original_Global

	local function loadModule(ns)
		local chunk, err = loadfile(modulePath)
		assert.is_nil(err)
		chunk("AddonName", ns)
		return ns
	end

	local function buildNamespace()
		return {
			-- minimal fields used by the target file
		}
	end

	before_each(function()
		original_Global = _G.SomeGlobal
		_G.SomeGlobal = {
			-- targeted stub
		}
	end)

	after_each(function()
		_G.SomeGlobal = original_Global
	end)

	it("does something observable", function()
		local ns = loadModule(buildNamespace())

		assert.is_true(ns.SomeFunction())
	end)
end)
```

## Results

Each run writes artifacts to `Testing/TestResults/`:

- `Testing/TestResults/busted.log` - terminal-style test output
- `Testing/TestResults/junit.xml` - JUnit XML for CI and GitHub reporting
- `Testing/TestResults/luacov.report.out` - line coverage report with overall summary

`busted` still prints its final terminal summary, for example:

```text
6 successes / 0 failures / 0 errors / 0 pending
```

The local runner also prints the overall coverage summary line from `LuaCov`, for example:

```text
Total           1234 346   78.10%
```

Coverage is evaluated against repository source `.lua` files, not just files that happened to be loaded during the current run. New source files are picked up automatically and show as `0%` until tests execute them.

## CI

The GitHub workflows use the same structure:

- `Publish Test Image` publishes the image from `Testing/Containerfile`
- `CI` pulls that image and runs the tests from `Testing/Tests`
- The GitHub Actions test view is driven directly from `Testing/TestResults/junit.xml`
- The GitHub Actions job summary includes the overall coverage line from `Testing/TestResults/luacov.report.out`