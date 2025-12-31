# Contributing

## Engine & Scope

- **Engine:** Godot Engine **4.5.1 (stable)**
- **Language:** GDScript
- **Intended use:** Modding APIs and infrastructure

All code should assume it will be:
- Used by third parties.
- Extended in unexpected ways.

## Types and Data

- Explicitly type all variables, function parameters, and return values.
- Avoid untyped lines unless there is a strong, documented technical reason.
- Take `Variant` as "unknown" (and untyped) and not as "any" - always validate and convert.
- Validate external input and mod data, do not assume it is well-formed.
- Use typed containers `Array[T], Dictionary[K, V]`. If not possible, document the reason clearly.

## Naming Conventions

- Use **descriptive names** that make sense with least possible context.
- Avoid 1–2 letter names except for:
  - loop iterators (`i`, `j`, `k`)
  - well-known math or coordinate symbols (`x`, `y`, `z`, `w`, `r`, `g`, `b`, `a`)
- File and folder names should reflect their role clearly.
- Avoid generic file/folder names like `utils`, `misc`, `stuff`.

## Project Structure

This repository is divided into two logical parts:
- Plugin: include `./addons/gsom_modapi/**`.
	- It will be installable from Godot Asset Library.
	- The main autoload class `GsomModapi`.
	- Other helper classes: core, meta, content, query.
	- Predefined content types.
	- Internal helpers to work with mods, content, and GDScript features.
- Demo: include `./**`, exclude `./addons/gsom_modapi/**`.
	- It is intended for testing, reference, and as a project template.
	- `run_as_game` launch as a player.
	- `run_as_mod` launch as a mod developer.
	- `./core/**` is responsible for startup logic and some key built-ins.
	- `./mods/**` ship all other parts of the game as "content".
	- Both Core and mods can register their content with `GsomModapi` during initialization.

Every logical component must **live in its own folder**, containing all of its
assets. Do not scatter related files across unrelated directories.

Example:
```
my_button/
├── my_button.tscn
├── my_button.gd
├── my_button_icon.png
├── subcomponent_1/
└── subcomponent_2/
```

## Architectural Guidelines

- Prefer **composition over inheritance**.
- Avoid deep inheritance hierarchies.
- Avoid hard-coded resource and node paths.
- Communicate via:
  - explicit interfaces,
  - signals,
  - clearly defined data structures.

Static singletons are allowed **only** for truly global systems and must be
documented as such.

## API Design Principles

This project is a **public API**.

Therefore:
- Breaking changes must be deliberate.
- Behavior should be predictable and boring.
- Errors should fail loudly and clearly.
- Silent fallback behavior is discouraged.

When in doubt, choose:
- Explicit over clever.
- Strict over permissive.
- Readable over short.

If something is required, enforce it.

If something is optional, define the default behavior clearly.

## What Not To Do

- No dynamic typing “for convenience”.
- No hidden logic in scenes.
- No reliance on editor-only behavior at runtime.
- No assumptions about mod correctness.
- No undocumented side effects.
