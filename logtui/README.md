# lt - Log TUI

A fast, vim-inspired terminal UI for managing daily log entries in markdown format.

## Features

- **Auto-discovery**: Automatically finds `YYYY.md` files in current directory
- **External editor integration**: Uses your `$EDITOR` (defaults to nvim) for writing
- **Vim-style navigation**: h/l for days, calendar for jumps
- **Search**: Full-text search across all entries
- **Calendar view**: Visual month view with entry indicators
- **Multiple entries per day**: Supports and organizes multiple log entries

## Installation

```bash
cd /Users/djpoo/log/2026/logtui
cargo install --path .
```

The binary `lt` will be installed to `~/.cargo/bin/lt` (ensure `~/.cargo/bin` is in your PATH).

## Usage

### Basic Usage

```bash
# Run from directory containing YYYY.md file (e.g., 2026.md)
cd /Users/djpoo/log/2026
lt

# Or specify a log file
lt /path/to/2026.md
```

### Keybindings

#### Daily View (Main)
- `h` - Previous day
- `l` - Next day
- `t` - Jump to today
- `c` - Open calendar picker
- `/` - Search mode
- `:` - Jump to specific date
- `n` - New quick entry (uses last location)
- `N` - New full entry (prompts for location)
- `i` - Edit entry (shows selection if multiple)
- `q` - Quit

#### Calendar View
- `h/l` - Previous/next day
- `j/k` - Previous/next week
- `Enter` - Select date and return to daily view
- `Esc` - Cancel and return

#### Search View
- Type to search (searches content and locations)
- `j/k` - Navigate results
- `Enter` - Jump to selected result's date
- `Esc` - Cancel

#### Entry Selection (when editing with multiple entries)
- `j/k` - Navigate entries
- `Enter` - Edit selected entry
- `Esc` - Cancel

#### Jump to Date
- Type date in format `YYYY-MM-DD`
- `Enter` - Jump to date
- `Esc` - Cancel

### Editor Integration

When creating or editing entries, `lt` suspends the TUI and launches your editor with:
- Auto-generated timestamp header
- Location field (pre-filled or editable)
- Comment lines with instructions (lines starting with `#` are ignored)

**Save and quit** (`:wq` in neovim) to save the entry, or quit without saving to cancel.

The editor used is determined by the `$EDITOR` environment variable (defaults to `nvim`).

## Log File Format

Log files follow this markdown format:

```markdown
# 2026 Log

## 2026-01-25 14:30:00 Sunday - Issaquah, WA

This is a log entry. You can write multiple paragraphs.

It supports full markdown but displays as plain text in the TUI.

## 2026-01-25 20:15:32 Sunday - Issaquah, WA

Multiple entries per day are supported and sorted by time.
```

### Entry Format
- Header: `## YYYY-MM-DD HH:MM:SS DayOfWeek - Location`
- Content: Any text following the header until the next header
- Entries are automatically sorted by date and time

## Environment Variables

- `$EDITOR` - Editor to use for creating/editing entries (default: `nvim`)

## Examples

### Quick Entry Workflow
```bash
$ cd ~/log/2026
$ lt
[TUI opens showing today's entries]
[Press 'n' - editor opens with timestamp and last location]
[Write entry, save with :wq]
[Back to TUI with new entry visible]
```

### Search Workflow
```bash
[In TUI, press '/']
[Type "project" to search]
[Press j/k to navigate results]
[Press Enter to jump to selected date]
```

### Calendar Navigation
```bash
[In TUI, press 'c']
[Use hjkl to navigate calendar]
[Dates with • have entries]
[Press Enter to select a date]
```

## Development

### Project Structure
```
logtui/
├── src/
│   ├── main.rs       # Entry point & event loop
│   ├── models.rs     # Data structures
│   ├── parser.rs     # Log file parsing & serialization
│   ├── storage.rs    # File I/O & discovery
│   ├── editor.rs     # External editor integration
│   ├── ui.rs         # TUI rendering
│   ├── calendar.rs   # Calendar view logic
│   └── search.rs     # Search functionality
├── Cargo.toml
└── README.md
```

### Building from Source
```bash
cargo build --release
```

### Running Tests
```bash
cargo test
```

## License

This is a personal tool. Use at your own risk.

## Troubleshooting

### "No log file found"
Ensure you're running `lt` from a directory containing a `YYYY.md` file (e.g., `2026.md`), or specify the file path explicitly:
```bash
lt /path/to/2026.md
```

### "Editor not found"
Set your `$EDITOR` environment variable:
```bash
export EDITOR=nvim  # or vim, nano, etc.
```

### Terminal colors look wrong
Ensure your terminal supports 256 colors and true color. Most modern terminals do.
