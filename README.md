# Goosespeed

Goosespeed is a fast 3D traversal game about being a goose, crossing land, water, and sky as quickly as possible.

The game is built around short replayable courses, route learning, immediate restarts, and momentum-focused movement. The goose does not unlock better stats or permanent upgrades. Progress comes from player skill, better lines, and cleaner execution.

## Project Status

This repository is the main Godot game project. It is currently an early shell: project settings are in place, but the first playable scene has not been added yet.

Target platform for the initial build:

- Windows PC
- Steam
- Steam Deck

The project currently uses:

- Godot 4.7
- Jolt Physics
- Forward Plus renderer

## Repository Scope

This repo contains the actual Godot game project only.

Sibling folders in the wider workspace are intentional:

- `../docs/` contains game design, planning, and messaging documents.
- `../assets_lib/` contains source assets and work-in-progress asset experiments.
- `../goose-moves/` is a separate Godot movement lab/library created for Goosespeed.

Those folders are kept outside this Godot project so unfinished assets, research notes, and movement experiments do not get imported into the game project by accident.

## Related Movement Work

`goose-moves` is used to research, compare, and test movement mechanics before they are integrated into the game. It includes controller prototypes, movement tuning, settings presets, and headless regression tests.

The intended relationship is:

1. Prototype and validate movement ideas in `goose-moves`.
2. Decide which mechanics belong in Goosespeed.
3. Integrate the selected movement code or behavior into this game project deliberately.

## Opening the Project

Open the `goosespeed/` folder in Godot 4.7 or newer.

From this workspace, the project can also be checked headlessly with:

```sh
HOME=/tmp XDG_DATA_HOME=/tmp /Applications/Godot.app/Contents/MacOS/godot --headless --path goosespeed --quit-after 1
```

At the moment this exits with "no main scene defined" because the first playable scene has not been created yet.

## Design Direction

The core experience should feel like one continuous movement sequence:

Run downhill, slide, launch, glide, land on a slope, enter water, swim with the current, leap out, fly through a shortcut, and sprint to the finish.

Design priorities:

- Speedrunning first
- Continuous momentum across movement states
- Simple controls with deep mastery
- Predictable arcade physics
- Chaotic but fair locations
- Immediate restarts
- Skill-based progression, not stat upgrades

The goose is already perfect.
