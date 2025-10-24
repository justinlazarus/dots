# AGENTS.md

## Build, Lint, and Test Commands
- **C (sketchybar/helpers):**
  - Build all: `make -C sketchybar/helpers`
  - Build single event provider: `make -C sketchybar/helpers/event_providers/cpu_load`
  - No automated tests or linter detected for C code.
- **Lua (nvim config):**
  - Format: Use [StyLua](https://github.com/JohnnyMorganz/StyLua) with `.stylua.toml` (2 spaces, Unix EOL, prefer single quotes).
  - No test or lint commands detected.
- **Shell scripts:**
  - Use `bash script.sh` to run. No lint/test detected.

## Code Style Guidelines
- **Imports:** Use relative imports for Lua; C includes use double quotes for local headers.
- **Formatting:**
  - Lua: 2 spaces, Unix line endings, single quotes preferred.
  - C#: 110 char print width, spaces, auto EOL.
- **Naming:**
  - Lua: snake_case or descriptive names for variables/functions.
  - C: snake_case for variables/functions, ALL_CAPS for macros.
- **Types:**
  - Lua: Dynamic, but prefer explicit local variables.
  - C: Use explicit types (int, float, struct), initialize variables.
- **Error Handling:**
  - C: Check argc, print usage, exit(1) on error.
  - Lua: Use `pcall` for error-prone calls if needed.
- **General:**
  - Keep code concise and readable.
  - Add comments for non-obvious logic.
  - Prefer explicit over implicit behavior.
