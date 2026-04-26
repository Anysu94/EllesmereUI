# Module Test Layout

This folder is reserved for specs that target addon submodules such as
`EllesmereUIActionBars`, `EllesmereUINameplates`, or `EllesmereUIUnitFrames`.

Keep module specs grouped by addon folder so the suite can scale without mixing
core addon tests and submodule behavior in the same place.

## Conventions

- Mirror the production folder structure under `Testing/Tests/Modules/`.
- Prefer file names like `<behavior>_spec.lua` or `<module>_spec.lua` that map clearly to one production file.
- Keep specs focused. If one production file has several independent helper clusters, split them only when the file becomes hard to navigate.
- Default to behavior-oriented examples, not snapshot-style dumps of large tables.
- When a spec intentionally documents a real bug, make that obvious in the example name and assertion message.

Examples in `Testing/Tests/Modules/CooldownManager/` are the current reference for style, helper layout, and bug-oriented assertions.