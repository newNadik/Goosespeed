# GooseSpeed Project Agent Process

This is the main GooseSpeed Godot project.

## Required Workflow

- Inspect first, then present a short plan.
- Wait for explicit user confirmation before changing files.
- Keep changes scoped to the confirmed task.
- If the implementation direction changes, stop and confirm the revised plan.

## Cleanup Before Done

- Remove temporary or obsolete scenes, scripts, assets, and `.uid` files created
  by the task.
- Remove stale Godot editor/cache references when they cause missing dependency
  dialogs or warnings.
- Search for deleted names and old action names with `rg`.
- Fix warnings introduced by the task.

## Validation Before Done

Use the relevant checks:

```sh
env HOME=/tmp XDG_DATA_HOME=/tmp /Applications/Godot.app/Contents/MacOS/godot --headless --path . --quit-after 1
env HOME=/tmp XDG_DATA_HOME=/tmp /Applications/Godot.app/Contents/MacOS/godot --headless --path . scenes/test/goosespeed_movement_lab.tscn --quit-after 1
env HOME=/tmp XDG_DATA_HOME=/tmp /Applications/Godot.app/Contents/MacOS/godot --headless --path . --script tests/test_input_map.gd
env HOME=/tmp XDG_DATA_HOME=/tmp /Applications/Godot.app/Contents/MacOS/godot --headless --path . tests/test_movement_backends.tscn
```

Add tests where practical. Do not leave validation-only scripts or debug scenes
behind unless they are intentional project tests.

## Commit Rule

- Commit only stable, cleaned, validated work.
- Commit only intentional files for the confirmed task.
- Do not commit unrelated user changes.
- If validation cannot be completed, ask before committing.

## Input And Prototype Alignment

- Shared movement input actions should stay aligned with `goose-moves`:
  `player_forward`, `player_back`, `player_left`, `player_right`,
  `player_jump`, `player_crouch`, `player_special`, and `player_walk`.
- GooseSpeed-specific player actions should use the same `player_*` convention.
- `goose-moves/` remains the movement reference. Reuse its scale, fixtures, UI
  flow, and button conventions, but do not pull movement internals into this
  project without a confirmed integration plan.
- During temporary movement integration, `external/goose-moves` and the root
  `res://scripts`, `res://scenes`, and `res://data` aliases may point at
  symlinked `goose-moves` files. Treat those as development-only wiring to be
  removed before release.
