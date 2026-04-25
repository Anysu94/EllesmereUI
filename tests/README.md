# EllesmereUI Unit Tests

This directory contains standalone Lua unit tests for EllesmereUI using `busted`.
The suite runs outside World of Warcraft with a minimal WoW API bootstrap in `bootstrap.lua`.

`busted` is configured centrally in `.busted`, so helper loading and spec discovery do not need to be repeated in every command.

## Structure

- `bootstrap.lua` - loads WoW API stubs and then loads `EllesmereUI.lua`
- `ellesmereui_spec.lua` - `busted` specs for core helpers

## Prerequisites

- Lua 5.1
- LuaRocks
- `busted` installed for Lua 5.1

Example install:

```bash
luarocks --lua-version=5.1 install busted
```

## Run Tests

From the repository root:

```bash
busted tests
```

To run only the core helper spec:

```bash
busted tests/ellesmereui_spec.lua
```

## Notes

- Tests should target real code from `EllesmereUI.lua`, not local mock reimplementations.
- Add new specs as `*_spec.lua` files so `busted` picks them up automatically.
- On Windows, running through WSL is usually the simplest Lua 5.1 setup.

## Run In Podman

The intended local workflow is:

1. Publish the test runner image once to GHCR.
2. Mount your checkout into the container.
3. Re-run tests without rebuilding unless the toolchain image itself changes.

The CI workflow pulls a prebuilt image from GitHub Container Registry instead of rebuilding it on every test run.

Publish or refresh that image through the `Publish Test Image` workflow whenever `Containerfile.tests` changes.

Local runs use the same GHCR image by default:

```powershell
.\tests\run-tests.ps1
```

Run the suite against your current checkout:

```bash
podman run --rm -v "$PWD:/workspace:Z" -w /workspace ghcr.io/<owner>/ellesmereui-tests:latest tests
```

On PowerShell, use `${PWD}` for the bind mount source:

```powershell
podman run --rm -v "${PWD}:/workspace:Z" -w /workspace ghcr.io/<owner>/ellesmereui-tests:latest tests
```

If you want to rebuild the image locally while working on `Containerfile.tests` itself:

```powershell
.\tests\run-tests.ps1 -Build -ImageName ellesmereui-tests:latest
```

If your GHCR package is private, authenticate locally first:

```powershell
podman login ghcr.io
```

Every local run writes artifacts to `.testresults/`:

- `.testresults/busted.log` - terminal-style test output
- `.testresults/junit.xml` - JUnit XML for CI and report tooling

If SELinux relabeling is not needed on your machine, you can drop the `:Z` suffix from the bind mount.

Because the image only contains Lua, LuaRocks and `busted`, you only rebuild it when `Containerfile.tests` changes or when you want newer tool versions.

## Test Summary And Results

`busted` prints a final summary line automatically, for example:

```text
6 successes / 0 failures / 0 errors / 0 pending
```

That is the overview of how many unit tests passed, failed, or were skipped.

The same run also writes `.testresults/junit.xml`, which GitHub Actions publishes and renders in the pipeline via the JUnit report step.
