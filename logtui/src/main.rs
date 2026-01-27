mod editor;
mod models;
mod parser;
mod search;
mod storage;
mod summary;
mod ui;

use anyhow::{Context, Result};
use chrono::{Datelike, Local, NaiveDate};
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyModifiers},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use models::{AppMode, AppState, TagFilter};
use ratatui::{backend::CrosstermBackend, Terminal};
use std::collections::HashMap;
use std::io;
use std::io::Write;
use std::path::PathBuf;

fn main() -> Result<()> {
    // Parse CLI arguments
    let cli_path = std::env::args().nth(1).map(PathBuf::from);

    // Find log file
    let log_path = storage::find_log_file(cli_path).context("Failed to find log file")?;

    // Extract year from filename
    let year = storage::extract_year_from_filename(&log_path)
        .context("Failed to extract year from filename")?;

    // Create file if it doesn't exist
    storage::create_log_file_if_missing(&log_path, year)?;

    // Load entries
    let content = storage::read_log_file(&log_path)?;
    let entries = parser::parse_log_file(&content, year)?;

    // Load summaries
    let summary_content = storage::read_summary_file(&log_path)?;
    let monthly_summaries = summary::parse_summary_file(&summary_content, year)?;

    // Initialize app state
    let mut app = AppState::new(log_path, year, entries);
    app.monthly_summaries = monthly_summaries;

    // Initialize tag state for current date
    update_tag_state(&mut app);

    // Setup terminal
    enable_raw_mode().context("Failed to enable raw mode")?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)
        .context("Failed to setup terminal")?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend).context("Failed to create terminal")?;

    // Run the app
    let res = run_app(&mut terminal, &mut app);

    // Restore terminal
    disable_raw_mode().context("Failed to disable raw mode")?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )
    .context("Failed to restore terminal")?;
    terminal.show_cursor().context("Failed to show cursor")?;

    if let Err(err) = res {
        eprintln!("Error: {:?}", err);
    }

    Ok(())
}

fn run_app<B: ratatui::backend::Backend + Write>(
    terminal: &mut Terminal<B>,
    app: &mut AppState,
) -> Result<()> {
    loop {
        terminal.draw(|f| ui::render(f, app))?;

        if app.should_quit {
            break;
        }

        if let Event::Key(key) = event::read()? {
            handle_key_event(app, key.code, key.modifiers, terminal)?;
        }
    }

    Ok(())
}

fn update_tag_state(app: &mut AppState) {
    let entries = app.get_entries_for_date(&app.current_date);

    if entries.is_empty() {
        app.available_tags = Vec::new();
        app.untagged_count = 0;
        app.current_tag_filter = TagFilter::All;
        return;
    }

    // Count entries per tag
    let mut tag_counts: HashMap<String, usize> = HashMap::new();
    let mut untagged_count = 0;

    for entry in &entries {
        match &entry.tag {
            Some(tag) => *tag_counts.entry(tag.clone()).or_insert(0) += 1,
            None => untagged_count += 1,
        }
    }

    // Sort tags by count (descending), then alphabetically
    let mut tags: Vec<(String, usize)> = tag_counts.into_iter().collect();
    tags.sort_by(|a, b| {
        b.1.cmp(&a.1) // Count descending
            .then_with(|| a.0.cmp(&b.0)) // Then alphabetically
    });

    // Always default to All filter
    let default_filter = TagFilter::All;

    app.available_tags = tags;
    app.untagged_count = untagged_count;
    app.current_tag_filter = default_filter;
}

enum Direction {
    Next,
    Prev,
}

fn cycle_tag_filter(app: &mut AppState, direction: Direction) {
    // Build filter list: all first, then tags by count, then untagged (if any)
    let mut filters: Vec<TagFilter> = Vec::new();

    // Add "all" at the beginning
    filters.push(TagFilter::All);

    // Add all tags (already sorted by count)
    for (tag, _) in &app.available_tags {
        filters.push(TagFilter::Tag(tag.clone()));
    }

    // Add untagged if present
    if app.untagged_count > 0 {
        filters.push(TagFilter::Untagged);
    }

    if filters.is_empty() {
        return; // No filters available
    }

    // Find current position
    let current_idx = filters
        .iter()
        .position(|f| f == &app.current_tag_filter)
        .unwrap_or(0);

    // Calculate next position
    let new_idx = match direction {
        Direction::Next => (current_idx + 1) % filters.len(),
        Direction::Prev => (current_idx + filters.len() - 1) % filters.len(),
    };

    app.current_tag_filter = filters[new_idx].clone();
    app.scroll_offset = 0; // Reset scroll when filtering
}

fn handle_key_event<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    key: KeyCode,
    modifiers: KeyModifiers,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    match &app.mode {
        AppMode::DailyView => handle_daily_view_keys(app, key, modifiers, terminal),
        AppMode::SelectEntry => handle_select_entry_keys(app, key, terminal),
        AppMode::SearchView => handle_search_keys(app, key, modifiers),
        AppMode::DaySearchView => handle_day_search_keys(app, key),
        AppMode::QuickEntry | AppMode::FullEntry | AppMode::EditEntry(_) => {
            // Should not receive keys while external editor is open
            Ok(())
        }
    }
}

fn handle_daily_view_keys<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    key: KeyCode,
    modifiers: KeyModifiers,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    match key {
        KeyCode::Char('q') => {
            app.should_quit = true;
        }
        KeyCode::Char('s') if modifiers.contains(KeyModifiers::CONTROL) => {
            // Ctrl+s: Global search across all days
            app.search_query.clear();
            app.search_results.clear();
            app.selected_entry_index = 0;
            app.mode = AppMode::SearchView;
        }
        KeyCode::Char('n') if modifiers.contains(KeyModifiers::CONTROL) => {
            // Ctrl+n: Jump to first day of next month
            if let Some(new_year) = app.jump_to_next_month() {
                // Year boundary crossed - try to load new year's file
                if let Err(e) = app.reload_from_year(new_year) {
                    // If file doesn't exist, stay on current year's last month
                    eprintln!("Warning: Could not load year {}: {}", new_year, e);
                    app.jump_to_prev_month(); // Go back to previous month
                }
            }
            app.scroll_offset = 0;
            app.day_search_query.clear();
            update_tag_state(app);
        }
        KeyCode::Char('p') if modifiers.contains(KeyModifiers::CONTROL) => {
            // Ctrl+p: Jump to first day of previous month
            if let Some(new_year) = app.jump_to_prev_month() {
                // Year boundary crossed - try to load new year's file
                if let Err(e) = app.reload_from_year(new_year) {
                    // If file doesn't exist, stay on current year's first month
                    eprintln!("Warning: Could not load year {}: {}", new_year, e);
                    app.jump_to_next_month(); // Go back to next month
                }
            }
            app.scroll_offset = 0;
            app.day_search_query.clear();
            update_tag_state(app);
        }
        KeyCode::Char('j') => {
            app.next_day(); // j = next day (forward in time)
            app.scroll_offset = 0;
            app.day_search_query.clear();
            update_tag_state(app);
        }
        KeyCode::Char('k') => {
            app.prev_day(); // k = previous day (backward in time)
            app.scroll_offset = 0;
            app.day_search_query.clear();
            update_tag_state(app);
        }
        KeyCode::Char('h') => {
            cycle_tag_filter(app, Direction::Prev);
        }
        KeyCode::Char('l') => {
            cycle_tag_filter(app, Direction::Next);
        }
        KeyCode::Char('t') => {
            app.jump_to_today();
            app.scroll_offset = 0;
            app.day_search_query.clear();
            update_tag_state(app);
        }
        KeyCode::Char('/') => {
            // Day search with highlighting
            app.day_search_query.clear();
            app.mode = AppMode::DaySearchView;
        }
        KeyCode::Char('i') => {
            // Edit existing entry or create new entry
            handle_edit_or_create_entry(app, terminal)?;
        }
        KeyCode::Char('I') => {
            // Edit summary
            handle_edit_summary(app, terminal)?;
        }
        KeyCode::Char('d') if modifiers.contains(KeyModifiers::CONTROL) => {
            // Ctrl+d: Scroll down one page (viewport height)
            app.scroll_offset = app.scroll_offset.saturating_add(app.viewport_height);
        }
        KeyCode::Char('u') if modifiers.contains(KeyModifiers::CONTROL) => {
            // Ctrl+u: Scroll up one page (viewport height)
            app.scroll_offset = app.scroll_offset.saturating_sub(app.viewport_height);
        }
        KeyCode::Char('d') => {
            // d: Scroll down one line
            app.scroll_offset = app.scroll_offset.saturating_add(1);
        }
        KeyCode::Char('u') => {
            // u: Scroll up one line
            app.scroll_offset = app.scroll_offset.saturating_sub(1);
        }
        KeyCode::Down => {
            app.scroll_offset = app.scroll_offset.saturating_add(1);
        }
        KeyCode::Up => {
            app.scroll_offset = app.scroll_offset.saturating_sub(1);
        }
        KeyCode::PageDown => {
            app.scroll_offset = app.scroll_offset.saturating_add(app.viewport_height);
        }
        KeyCode::PageUp => {
            app.scroll_offset = app.scroll_offset.saturating_sub(app.viewport_height);
        }
        _ => {}
    }
    Ok(())
}

fn handle_select_entry_keys<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    key: KeyCode,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    match key {
        KeyCode::Esc => {
            app.mode = AppMode::DailyView;
        }
        KeyCode::Char('j') | KeyCode::Down => {
            let entries = app.get_entries_for_date(&app.current_date);
            // +1 for "+ New Entry" option at index 0
            if app.selected_entry_index + 1 <= entries.len() {
                app.selected_entry_index += 1;
            }
        }
        KeyCode::Char('k') | KeyCode::Up => {
            if app.selected_entry_index > 0 {
                app.selected_entry_index -= 1;
            }
        }
        KeyCode::Enter => {
            let idx = app.selected_entry_index;

            if idx == 0 {
                // "+ New Entry" was selected - create new entry
                app.mode = AppMode::DailyView;
                handle_create_new_entry(app, terminal)?;
            } else {
                // Existing entry was selected - edit it
                // Subtract 1 because index 0 is "+ New Entry"
                let entry_idx = idx - 1;
                let entries = app.get_entries_for_date(&app.current_date);

                if let Some(entry) = entries.get(entry_idx) {
                    let date_str = entry.date.format("%Y-%m-%d").to_string();
                    let time_str = entry.time.format("%H:%M:%S").to_string();

                    // Suspend TUI and launch editor
                    suspend_tui(terminal)?;

                    let result = editor::edit_existing_entry(
                        &date_str,
                        &time_str,
                        &entry.day_of_week,
                        &entry.location,
                        &entry.content,
                        entry.tag.as_deref(),
                    )?;

                    resume_tui(terminal)?;

                    if let Some((date_str, time_str, day_of_week, location, content, tag)) = result
                    {
                        // Parse the updated date and time
                        use chrono::NaiveDate as ChronoDate;
                        use chrono::NaiveTime as ChronoTime;

                        let new_date = ChronoDate::parse_from_str(&date_str, "%Y-%m-%d")
                            .context("Invalid date format")?;
                        let new_time = ChronoTime::parse_from_str(&time_str, "%H:%M:%S")
                            .context("Invalid time format")?;

                        // Update entry with new datetime
                        let mut updated_entry = entry.clone();
                        updated_entry.date = new_date;
                        updated_entry.time = new_time;
                        updated_entry.day_of_week = day_of_week;
                        updated_entry.location = location.clone();
                        updated_entry.content = content;
                        updated_entry.tag = tag;

                        let serialized = parser::update_entry(
                            &mut app.entries,
                            app.current_date,
                            entry_idx,
                            updated_entry,
                            app.year,
                        )?;

                        storage::write_log_file(&app.log_file_path, &serialized)?;
                        app.last_location = Some(location);
                        update_tag_state(app);
                    }
                }

                app.mode = AppMode::DailyView;
            }
        }
        _ => {}
    }
    Ok(())
}

fn handle_search_keys(app: &mut AppState, key: KeyCode, modifiers: KeyModifiers) -> Result<()> {
    match key {
        KeyCode::Esc => {
            app.mode = AppMode::DailyView;
        }
        KeyCode::Char('n') if modifiers.contains(KeyModifiers::CONTROL) => {
            // Ctrl+n: next result
            if app.selected_entry_index + 1 < app.search_results.len() {
                app.selected_entry_index += 1;
            }
        }
        KeyCode::Char('p') if modifiers.contains(KeyModifiers::CONTROL) => {
            // Ctrl+p: previous result
            if app.selected_entry_index > 0 {
                app.selected_entry_index -= 1;
            }
        }
        KeyCode::Down => {
            // Arrow down: next result
            if app.selected_entry_index + 1 < app.search_results.len() {
                app.selected_entry_index += 1;
            }
        }
        KeyCode::Up => {
            // Arrow up: previous result
            if app.selected_entry_index > 0 {
                app.selected_entry_index -= 1;
            }
        }
        KeyCode::Backspace => {
            app.search_query.pop();
            app.search_results = search::search_entries(app, &app.search_query);
            app.selected_entry_index = 0;
        }
        KeyCode::Enter => {
            if let Some((date, _)) = app.search_results.get(app.selected_entry_index) {
                app.current_date = *date;
                app.day_search_query.clear();
                app.mode = AppMode::DailyView;
                update_tag_state(app);
            }
        }
        KeyCode::Char(c) => {
            // Any character (including j and k) gets added to search
            app.search_query.push(c);
            app.search_results = search::search_entries(app, &app.search_query);
            app.selected_entry_index = 0;
        }
        _ => {}
    }
    Ok(())
}

fn handle_day_search_keys(app: &mut AppState, key: KeyCode) -> Result<()> {
    match key {
        KeyCode::Esc => {
            // Clear search and return to daily view
            app.day_search_query.clear();
            app.mode = AppMode::DailyView;
        }
        KeyCode::Enter => {
            // Keep highlighting and return to daily view
            app.mode = AppMode::DailyView;
        }
        KeyCode::Backspace => {
            app.day_search_query.pop();
        }
        KeyCode::Char(c) => {
            // Add character to search query
            app.day_search_query.push(c);
        }
        _ => {}
    }
    Ok(())
}

fn handle_edit_or_create_entry<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    _terminal: &mut Terminal<B>,
) -> Result<()> {
    // Always show selection menu with "+ New Entry" option at top
    app.selected_entry_index = 0;
    app.mode = AppMode::SelectEntry;
    Ok(())
}

fn handle_create_new_entry<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    // Always use last location (can be changed in editor)
    let location = app.last_location.clone();

    // Determine default tag based on current filter
    let default_tag = match &app.current_tag_filter {
        TagFilter::Tag(tag) => Some(tag.clone()),
        TagFilter::Untagged => Some("log".to_string()),
        TagFilter::All => Some("log".to_string()),
    };

    // Check if current_date is today
    let today = Local::now().date_naive();
    let is_today = app.current_date == today;

    // Suspend TUI and launch editor
    suspend_tui(terminal)?;

    let result = editor::edit_new_entry(location, default_tag, app.current_date, is_today)?;

    resume_tui(terminal)?;

    if let Some((location, content, tag)) = result {
        // Create new entry for the selected date
        let entry_time = if is_today {
            // Use actual current time for today
            Local::now().time()
        } else {
            // Use 00:00:00 sentinel for retrospective entries (no time)
            chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap()
        };

        let day_of_week = app.current_date.format("%A").to_string();

        let mut entry = models::LogEntry::new(
            app.current_date,
            entry_time,
            day_of_week,
            location.clone(),
            content,
        );
        entry.tag = tag;

        // Add to entries and serialize
        let serialized = parser::add_entry(&mut app.entries, entry, app.year);
        storage::write_log_file(&app.log_file_path, &serialized)?;

        app.last_location = Some(location);

        // Update tag state after adding new entry
        update_tag_state(app);
    }

    Ok(())
}

fn handle_edit_summary<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    let date_str = app.current_date.format("%Y-%m-%d").to_string();
    let current_summary = app.monthly_summaries.get_summary(&app.current_date);

    suspend_tui(terminal)?;

    let result = editor::edit_summary(&date_str, &current_summary)?;

    resume_tui(terminal)?;

    if let Some(new_summary) = result {
        // Update in-memory summary
        app.monthly_summaries
            .summaries
            .insert(app.current_date, new_summary.clone());

        // Read entire summary file, update this date, and write back
        let summary_content = storage::read_summary_file(&app.log_file_path)?;
        let updated_content =
            update_summary_in_file(&summary_content, app.current_date, &new_summary, app.year)?;
        storage::write_summary_file(&app.log_file_path, &updated_content)?;
    }

    Ok(())
}

/// Update or add a summary for a specific date in the summary file content
fn update_summary_in_file(
    content: &str,
    date: NaiveDate,
    new_summary: &str,
    _year: i32,
) -> Result<String> {
    use regex::Regex;

    let month = date.month();
    let day = date.day();
    let date_pattern = format!("{:02}/{:02}", month, day);

    let entry_re = Regex::new(r"^-\s*(\d{2})/(\d{2})\s*-?\s*(.*)$").unwrap();

    let mut lines: Vec<String> = content.lines().map(|s| s.to_string()).collect();
    let mut found = false;

    // Try to find and update existing entry
    for line in &mut lines {
        if let Some(caps) = entry_re.captures(line) {
            let entry_month: u32 = caps.get(1).unwrap().as_str().parse().unwrap();
            let entry_day: u32 = caps.get(2).unwrap().as_str().parse().unwrap();

            if entry_month == month && entry_day == day {
                // Update existing entry
                if new_summary.is_empty() {
                    // Remove the line if summary is empty
                    *line = String::new();
                } else {
                    *line = format!("- {} {}", date_pattern, new_summary);
                }
                found = true;
                break;
            }
        }
    }

    // If not found and summary is not empty, add new entry
    if !found && !new_summary.is_empty() {
        // Find the right section to add the entry
        let month_name = chrono::Month::try_from(month as u8)
            .ok()
            .and_then(|m| Some(format!("{}", m.name())))
            .unwrap_or_else(|| "Unknown".to_string());

        let mut insert_pos = None;
        let mut in_month = false;

        for (i, line) in lines.iter().enumerate() {
            // Check if we're in the right month section
            if line.starts_with("## ") && line.contains(&month_name) {
                in_month = true;
                continue;
            }

            // If we hit another month section, stop
            if in_month && line.starts_with("## ") {
                insert_pos = Some(i);
                break;
            }

            // Look for the right place to insert (sorted by day)
            if in_month {
                if let Some(caps) = entry_re.captures(line) {
                    let entry_month: u32 = caps.get(1).unwrap().as_str().parse().unwrap_or(0);
                    let entry_day: u32 = caps.get(2).unwrap().as_str().parse().unwrap_or(0);

                    if entry_month == month && entry_day > day {
                        insert_pos = Some(i);
                        break;
                    }
                }
            }
        }

        // Insert the new entry
        let new_line = format!("- {} {}", date_pattern, new_summary);
        if let Some(pos) = insert_pos {
            lines.insert(pos, new_line);
        } else if in_month {
            // Add at end
            lines.push(new_line);
        } else {
            // Month section doesn't exist, create it
            lines.push(String::new());
            lines.push(format!("## {}", month_name));
            lines.push(String::new());
            lines.push(new_line);
        }
    }

    // Filter out empty lines that were marked for removal
    let result = lines
        .into_iter()
        .filter(|line| !line.is_empty() || line.trim().is_empty())
        .collect::<Vec<_>>()
        .join("\n");

    Ok(result)
}

fn suspend_tui<B: ratatui::backend::Backend + Write>(terminal: &mut Terminal<B>) -> Result<()> {
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    Ok(())
}

fn resume_tui<B: ratatui::backend::Backend + Write>(terminal: &mut Terminal<B>) -> Result<()> {
    enable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        EnterAlternateScreen,
        EnableMouseCapture
    )?;
    terminal.clear()?;
    Ok(())
}
