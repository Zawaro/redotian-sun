# Conventions

Project `AGENTS.md` is the full source; durable highlights that prevent mistakes:

- Indentation: **4 spaces, never tabs** (mixing causes Redot parse errors).
- **Type hints REQUIRED** on every variable, parameter, and return value.
- **Signal up, call down**: children emit, parents connect. Typed `name.emit(args)`, never `emit_signal("name", args)`.
- Errors: `push_error()` + `return` for runtime guards. Never `assert()` for runtime checks (stripped in release). Use `is_instance_valid()` after potential free.
- Comments: do not add unless asked. `##` doc comments only to describe an `@export` for the Inspector; `#` for logic.
- **Two editor concepts — never conflate**: Redot IDE (`Engine.is_editor_hint()`) vs in-game Map Editor (`get_meta("is_map_editor")` on the MapEditor node).
- Script structure order: `class_name`/docs, signals, enums, `@export`, `const`, public vars, private vars, `@onready`, lifecycle (`_ready` -> `_process`...), public methods, private methods.
- Commits: Conventional Commits `type(scope): description (#issue)`. Branch `type/issue-number-kebab-description`. GH issue and PR titles use the conventional prefix; PR title also includes the issue number.
- `openspec/changes/` must be archived before merge; `openspec/specs/` is authoritative.
- Scene/script names mirror each other (PascalCase). Reuse existing helpers/data patterns before writing new ones.
