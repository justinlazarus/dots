# lt - Log TUI

A fast, vim-inspired terminal UI for managing daily log entries — now backed by a SQLite database (`logs.db`).

## Features

- SQLite-backed storage: entries are stored in `logs.db` for fast queries and migrations
- Interactive editor integration: opens your `$EDITOR` (defaults to `nvim`) for each entry
- Vim-style navigation: `h`/`l`/`j`/`k`, page scrolling, and calendar jumps
- Full-text search powered by SQL queries
- Calendar view and per-day summaries
- Multiple entries per day; each saved entry gets a unique ULID id

## Installation

From the project root:

```bash
cargo install --path .
```

This installs the `lt` binary (and the `migrate` helper if you build/install binaries) into `~/.cargo/bin` (ensure that is in your `PATH`).

## Usage

### Running the TUI

Run `lt` from the directory where you want the database to live. The app uses `logs.db` in the current directory by default; if it doesn't exist it will be created.

```bash
cd ~/log/2026
lt
```

The TUI shows the currently selected day and its entries. Use the keybindings below to navigate, edit, and create entries.

### Keybindings

Daily View (Main)
- `h` - Previous day
- `l` - Next day
- `t` - Jump to today
- `c` - Open calendar picker
- `/` - Day search (inline highlight)
- `Enter` - Open selection list or create new entry for the day
- `i` or `S` - Edit or insert a per-day summary
- `q` - Quit

Entry View & Selection
- `j`/`k` or Arrow keys - Navigate entries or scroll
- `n` - Create a new entry for the current date (editor opens)
- `Enter` - Edit selected entry (editor opens)
- `x` - Delete (requires confirmation)
- Numeric keys `1`..`9`, `0` - Open links detected in the entry body (uses OS opener)

### Editor Integration

When creating or editing an entry, `lt` suspends the TUI and launches your editor with a small markdown file that contains YAML frontmatter followed by the entry body. Frontmatter fields:

- `date`: `YYYY-MM-DD`
- `time`: `HH:MM:SS`
- `title`: optional title (stored in DB)
- `location`: optional location string
- `tag`: optional tag

Example editor buffer created for a new entry:

```markdown
---
date: 2026-01-25
time: 14:30:00
title: ""
location: Issaquah, WA
tag: log
---

Write your entry here.
```

Save and quit the editor to persist the entry; quit without saving to cancel. The editor used is determined by the `$EDITOR` environment variable; if unset the app falls back to `nvim`, then `vim`/`vi`.

## Log File Format (legacy)

The project still includes a parser for the legacy `YYYY.md` markdown format. Expected header format for each entry:

```
## YYYY-MM-DD HH:MM:SS DayOfWeek - Location [#tag]

Entry body...
```

Timeless entries (no explicit time) are allowed; the migrator and parser treat a missing time as `00:00:00` sentinel.

If you have existing `YYYY.md` files you can migrate them into `logs.db` with the included interactive migrator (see below).

## Migration tool: migrate

An interactive migrator is provided at `src/bin/migrate.rs`. It parses a markdown file (for example `2026.md`), then for each parsed entry opens your editor so you can review or edit the proposed entry before inserting it into `logs.db`.

Basic usage (from the project root):

```bash
# dry run (lists parsed entries, does not open editor or write DB)
cargo run --bin migrate -- --file /path/to/2026.md --dry-run

# interactive migration (opens editor per entry, inserts on confirmation)
cargo run --bin migrate -- --file /path/to/2026.md --db /path/to/logs.db
```

Per-entry prompts after editor save:
- `[Enter]` — Insert the entry into the DB (new ULID assigned)
- `s` — Skip this entry
- `e` — Edit the entry again
- `q` — Quit migration (persisted entries remain)

The migrator makes a timestamped backup copy of `logs.db` before writing. After migration the tool writes an `archive.md` snapshot (same format as earlier markdown exports) for your git workflow.

## Summaries

If a `summaries.md` file is present when `lt` starts, the app will parse it and import per-day summaries into the `summaries` table in the DB (one-time migration). Summaries are kept in-memory for quick UI access and can be edited from the TUI.

## Development

Project layout (important files):

```
logtui/
├── src/
│   ├── main.rs       # TUI binary (`lt`)
│   ├── bin/migrate.rs # interactive migrator
│   ├── models.rs     # data structures
│   ├── parser.rs     # legacy markdown parser
│   ├── db.rs         # sqlite storage, migrations, export
│   ├── editor.rs     # editor helpers & frontmatter parser
│   ├── ui.rs         # TUI rendering
│   └── summary.rs    # summary import/export
├── Cargo.toml
└── README.md
```

Build and run:

```bash
# build
cargo build --release

# run the TUI
cargo run --bin lt

# run migrator
cargo run --bin migrate -- --file /path/to/2026.md
```

## Troubleshooting

- "No DB found": the app creates `logs.db` automatically if missing. If you expect to use an existing DB, run `lt` from the directory containing `logs.db` or pass an absolute path to the migrator and move the file where you want it.
- "Editor not found": set your `$EDITOR` environment variable, e.g. `export EDITOR=nvim`.
- Terminal colors: ensure your terminal supports 256 colors / true color for best appearance.

## License

This is a personal tool. Use at your own risk.
