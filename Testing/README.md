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