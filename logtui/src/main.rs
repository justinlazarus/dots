mod db; // Replacing parser and storage with db
mod editor;
mod models;
mod search;
mod summary;
mod ui;

use anyhow::{Context, Result};
use chrono::{Datelike, Local};
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use models::{AppMode, AppState};
use ratatui::{backend::CrosstermBackend, Terminal};
use std::io;
use std::io::Write;
use std::path::PathBuf;

fn main() -> Result<()> {
    // 1. Setup Database Path
    // Instead of looking for 2026.md, we use a single .db file
    let db_path = PathBuf::from("logs.db");
    let database = db::Database::open(&db_path).context("Failed to open database")?;

    // 2. Initialize State
    let today = Local::now().date_naive();

    // Fetch initial entries for today from DB
    let initial_entries = database.get_entries_for_date(today)?;

    // Initialize application state
    let mut app = AppState::new(database, initial_entries);

    // If summaries.md exists, parse and write into DB (one-time migration)
    let summary_path = PathBuf::from("summaries.md");
    if summary_path.exists() {
        let content = std::fs::read_to_string(&summary_path)?;
        let ms = summary::parse_summary_file(&content, today.year())?;
        for (date, text) in ms.summaries.iter() {
            app.db.set_summary(*date, text)?;
        }
    }

    // Load summaries from DB into in-memory structure
    let mut monthly_summaries = summary::MonthlySummaries::new();
    for (date, text) in app.db.get_all_summaries()? {
        monthly_summaries.summaries.insert(date, text);
    }
    app.monthly_summaries = monthly_summaries;

    // We no longer track last_location in AppState — YAML frontmatter carries location now

    // 3. Setup Terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // 4. Main Event Loop
    let res = run_app(&mut terminal, &mut app);

    // 5. Cleanup and Auto-Export
    suspend_tui(&mut terminal)?;

    // This maintains your Git workflow: write DB back to Markdown on exit
    println!("Syncing database to markdown for git...");
    app.db
        .export_to_markdown(PathBuf::from("archive.md").as_path())?;

    if let Err(err) = res {
        println!("{:?}", err);
    }

    Ok(())
}

fn run_app<B: ratatui::backend::Backend + Write>(
    terminal: &mut Terminal<B>,
    app: &mut AppState,
) -> Result<()> {
    loop {
        terminal.draw(|f| ui::render(f, app))?;

        if let Event::Key(key) = event::read()? {
            if key.kind == event::KeyEventKind::Release {
                continue;
            }

            handle_key_event(app, key.code, key.modifiers, terminal)?;

            if app.should_quit {
                return Ok(());
            }
        }
    }
}

fn handle_key_event<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    key: KeyCode,
    modifiers: event::KeyModifiers,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    // Global quit mapping available from any view
    if let KeyCode::Char('q') = key {
        app.should_quit = true;
        return Ok(());
    }

    match &app.mode {
        AppMode::DailyView => handle_daily_view_keys(app, key, modifiers, terminal),
        AppMode::EntryView(_) => handle_entry_view_keys(app, key, modifiers, terminal),
        AppMode::ConfirmDelete(_) => handle_confirm_delete_keys(app, key, terminal),
        // SelectEntry variant removed from AppMode; its handler is no longer
        // reachable. Fall through to the default branch.
        // SearchView variant removed from AppMode; this branch should never
        // occur. Keep DaySearchView which is used.
        AppMode::DaySearchView => handle_day_search_keys(app, key),
        // All AppMode variants are handled explicitly; no-op for unexpected
        _ => Ok(()),
    }
}

fn handle_daily_view_keys<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    key: KeyCode,
    modifiers: event::KeyModifiers,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    match key {
        // Ctrl+n / Ctrl+p: navigate to next / previous month (clamp day to valid
        // day in the destination month).
        KeyCode::Char('n') if modifiers.contains(event::KeyModifiers::CONTROL) => {
            let cur = app.current_date;
            let mut year = cur.year();
            let mut month = cur.month() as i32 + 1; // next month
            if month > 12 {
                month = 1;
                year += 1;
            }
            // Try to preserve the day, but clamp to the last valid day of month
            let day = cur.day();
            let mut new_date = chrono::NaiveDate::from_ymd_opt(year, month as u32, day);
            if new_date.is_none() {
                // decrement day until we find a valid date
                let mut d = day as i32;
                while d > 0 {
                    d -= 1;
                    if let Some(dt) = chrono::NaiveDate::from_ymd_opt(year, month as u32, d as u32)
                    {
                        new_date = Some(dt);
                        break;
                    }
                }
            }
            if let Some(dt) = new_date {
                app.current_date = dt;
                app.entries = app.db.get_entries_for_date(app.current_date)?;
                app.scroll_offset = 0;
                app.day_search_query.clear();
            }
        }
        KeyCode::Char('p') if modifiers.contains(event::KeyModifiers::CONTROL) => {
            let cur = app.current_date;
            let mut year = cur.year();
            let mut month = cur.month() as i32 - 1; // prev month
            if month < 1 {
                month = 12;
                year -= 1;
            }
            let day = cur.day();
            let mut new_date = chrono::NaiveDate::from_ymd_opt(year, month as u32, day);
            if new_date.is_none() {
                let mut d = day as i32;
                while d > 0 {
                    d -= 1;
                    if let Some(dt) = chrono::NaiveDate::from_ymd_opt(year, month as u32, d as u32)
                    {
                        new_date = Some(dt);
                        break;
                    }
                }
            }
            if let Some(dt) = new_date {
                app.current_date = dt;
                app.entries = app.db.get_entries_for_date(app.current_date)?;
                app.scroll_offset = 0;
                app.day_search_query.clear();
            }
        }
        KeyCode::Char('q') => {
            app.should_quit = true;
        }
        KeyCode::Char('j') => {
            // Next day
            app.current_date = app.current_date.succ_opt().unwrap_or(app.current_date);
            app.entries = app.db.get_entries_for_date(app.current_date)?;
            app.scroll_offset = 0;
            app.day_search_query.clear();
        }
        KeyCode::Char('k') => {
            // Previous day
            app.current_date = app.current_date.pred_opt().unwrap_or(app.current_date);
            app.entries = app.db.get_entries_for_date(app.current_date)?;
            app.scroll_offset = 0;
            app.day_search_query.clear();
        }
        KeyCode::Char('t') => {
            // Jump to today
            app.current_date = Local::now().date_naive();
            app.entries = app.db.get_entries_for_date(app.current_date)?;
            app.scroll_offset = 0;
            app.day_search_query.clear();
        }
        KeyCode::Char('S') => {
            // Edit summary for the current date (prefill with existing summary)
            suspend_tui(terminal)?;

            let current = app.monthly_summaries.get_summary(&app.current_date);
            if let Some(new_text) = editor::edit_summary(app.current_date, &current)? {
                // Persist to DB (set_summary will delete if empty)
                app.db.set_summary(app.current_date, &new_text)?;
                // Update in-memory cache
                app.monthly_summaries
                    .set_summary(app.current_date, &new_text);
            }

            resume_tui(terminal)?;
        }
        KeyCode::Char('i') => {
            // Insert or edit summary for the current date: open editor
            // with existing text if present, otherwise empty body
            suspend_tui(terminal)?;

            let current = app.monthly_summaries.get_summary(&app.current_date);
            if let Some(new_text) = editor::edit_summary(app.current_date, &current)? {
                // Persist to DB (set_summary will delete if empty)
                app.db.set_summary(app.current_date, &new_text)?;
                // Update in-memory cache
                app.monthly_summaries
                    .set_summary(app.current_date, &new_text);
            }

            resume_tui(terminal)?;
        }
        KeyCode::Enter => {
            // Enter: open detail entry view for this date or create new if none
            app.entries = app.db.get_entries_for_date(app.current_date)?;
            if app.entries.is_empty() {
                handle_create_new_entry(app, terminal)?;
            } else {
                app.selected_entry_index = 0;
                app.mode = AppMode::EntryView(0);
            }
        }
        KeyCode::Char('/') => {
            // Day search with highlighting
            app.day_search_query.clear();
            app.mode = AppMode::DaySearchView;
        }
        KeyCode::Char('d') if modifiers.contains(event::KeyModifiers::CONTROL) => {
            // Ctrl+d: Scroll down one page
            app.scroll_offset = app.scroll_offset.saturating_add(app.viewport_height as u16);
        }
        KeyCode::Char('u') if modifiers.contains(event::KeyModifiers::CONTROL) => {
            // Ctrl+u: Scroll up one page
            app.scroll_offset = app.scroll_offset.saturating_sub(app.viewport_height as u16);
        }
        KeyCode::Char('d') => {
            // Scroll down one line
            app.scroll_offset = app.scroll_offset.saturating_add(1);
        }
        KeyCode::Char('u') => {
            // Scroll up one line
            app.scroll_offset = app.scroll_offset.saturating_sub(1);
        }
        KeyCode::Down => {
            app.scroll_offset = app.scroll_offset.saturating_add(1);
        }
        KeyCode::Up => {
            app.scroll_offset = app.scroll_offset.saturating_sub(1);
        }
        KeyCode::PageDown => {
            app.scroll_offset = app.scroll_offset.saturating_add(app.viewport_height as u16);
        }
        KeyCode::PageUp => {
            app.scroll_offset = app.scroll_offset.saturating_sub(app.viewport_height as u16);
        }
        _ => {}
    }
    Ok(())
}

// Selection view removed; helper kept for reference but unused. If you want
// to delete this function entirely, say so and I'll remove it.

fn handle_search_keys(
    app: &mut AppState,
    key: KeyCode,
    modifiers: event::KeyModifiers,
) -> Result<()> {
    match key {
        KeyCode::Esc => {
            app.mode = AppMode::DailyView;
        }
        KeyCode::Char('n') if modifiers.contains(event::KeyModifiers::CONTROL) => {
            // Next result
            if app.selected_entry_index + 1 < app.search_results.len() {
                app.selected_entry_index += 1;
            }
        }
        KeyCode::Char('p') if modifiers.contains(event::KeyModifiers::CONTROL) => {
            // Previous result
            if app.selected_entry_index > 0 {
                app.selected_entry_index -= 1;
            }
        }
        KeyCode::Down => {
            if app.selected_entry_index + 1 < app.search_results.len() {
                app.selected_entry_index += 1;
            }
        }
        KeyCode::Up => {
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
                app.entries = app.db.get_entries_for_date(app.current_date)?;
                app.day_search_query.clear();
                app.mode = AppMode::DailyView;
            }
        }
        KeyCode::Char(c) => {
            // Add character to search
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

fn handle_entry_view_keys<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    key: KeyCode,
    modifiers: event::KeyModifiers,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    match key {
        KeyCode::Char('j') | KeyCode::Down => {
            let max = app.entries.len();
            if max > 0 && app.selected_entry_index + 1 < max {
                app.selected_entry_index += 1;
            }
        }
        KeyCode::Char('k') | KeyCode::Up => {
            if app.selected_entry_index > 0 {
                app.selected_entry_index -= 1;
            }
        }
        KeyCode::Enter => {
            // Edit current entry
            let idx = app.selected_entry_index;
            handle_edit_entry(app, terminal, idx)?;
        }
        KeyCode::Char('n') => {
            // New entry for this date
            handle_create_new_entry(app, terminal)?;
            // Refresh and move to last entry
            app.entries = app.db.get_entries_for_date(app.current_date)?;
            if !app.entries.is_empty() {
                app.selected_entry_index = app.entries.len() - 1;
            }
            app.mode = AppMode::EntryView(app.selected_entry_index);
        }
        KeyCode::Char('x') => {
            // Confirm delete
            let idx = app.selected_entry_index;
            app.mode = AppMode::ConfirmDelete(idx);
        }
        KeyCode::Esc => {
            app.mode = AppMode::DailyView;
        }
        KeyCode::Char('d') if modifiers.contains(event::KeyModifiers::CONTROL) => {
            // Ctrl+d: Scroll down one page
            app.scroll_offset = app.scroll_offset.saturating_add(app.viewport_height as u16);
        }
        KeyCode::Char('u') if modifiers.contains(event::KeyModifiers::CONTROL) => {
            // Ctrl+u: Scroll up one page
            app.scroll_offset = app.scroll_offset.saturating_sub(app.viewport_height as u16);
        }
        KeyCode::Char('d') => {
            // Scroll down one line
            app.scroll_offset = app.scroll_offset.saturating_add(1);
        }
        KeyCode::Char('u') => {
            // Scroll up one line
            app.scroll_offset = app.scroll_offset.saturating_sub(1);
        }
        _ => {}
    }
    Ok(())
}

fn handle_confirm_delete_keys<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    key: KeyCode,
    _terminal: &mut Terminal<B>,
) -> Result<()> {
    match key {
        KeyCode::Char('y') | KeyCode::Enter => {
            let idx = match app.mode {
                AppMode::ConfirmDelete(i) => i,
                _ => 0,
            };
            if let Some(entry) = app.entries.get(idx) {
                app.db.delete_entry(&entry.id)?;
            }
            // Refresh entries and clamp
            app.entries = app.db.get_entries_for_date(app.current_date)?;
            if app.entries.is_empty() {
                app.mode = AppMode::DailyView;
            } else {
                app.selected_entry_index = idx.min(app.entries.len() - 1);
                app.mode = AppMode::EntryView(app.selected_entry_index);
            }
        }
        KeyCode::Char('n') | KeyCode::Esc => {
            // Cancel
            if let AppMode::ConfirmDelete(idx) = app.mode {
                app.mode = AppMode::EntryView(idx);
            } else {
                app.mode = AppMode::DailyView;
            }
        }
        _ => {}
    }
    Ok(())
}

// Removed unused helper `handle_edit_or_create_entry` — selection flow
// is driven directly by key handlers. Deleting it reduces warnings.

fn handle_create_new_entry<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    suspend_tui(terminal)?;

    // Use the last entry's location for prefill if available; otherwise leave empty
    let last_loc = app.entries.last().map(|e| e.location.clone());
    eprintln!(
        "DEBUG: Creating new entry for date: {}, last_loc: {:?}",
        app.current_date, last_loc
    );

    let result = editor::edit_new_entry(
        last_loc,
        None,
        app.current_date,
        app.current_date == Local::now().date_naive(),
    )?;

    eprintln!(
        "DEBUG: Editor returned: {:?}",
        result
            .as_ref()
            .map(|(loc, content, tag)| (loc, content.len(), tag))
    );

    if let Some((location, content, tag)) = result {
        let entry = models::LogEntry {
            id: ulid::Ulid::new().to_string(),
            date: app.current_date,
            time: Local::now().time(),
            location,
            tag,
            content,
        };

        eprintln!(
            "DEBUG: Saving entry - id: {}, date: {}, time: {}, location: {}",
            entry.id, entry.date, entry.time, entry.location
        );

        // Save to SQLite
        app.db.save_entry(&entry)?;
        // No global last_location tracking — metadata lives in YAML
        eprintln!("DEBUG: Entry saved successfully");

        // Refresh local view
        app.entries = app.db.get_entries_for_date(app.current_date)?;
        eprintln!("DEBUG: Refreshed entries, count: {}", app.entries.len());
    } else {
        eprintln!("DEBUG: Editor returned None (cancelled)");
    }

    app.mode = AppMode::DailyView;
    resume_tui(terminal)?;
    Ok(())
}

fn handle_edit_entry<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    terminal: &mut Terminal<B>,
    entry_idx: usize,
) -> Result<()> {
    if let Some(entry) = app.entries.get(entry_idx).cloned() {
        suspend_tui(terminal)?;

        let date_str = entry.date.to_string();
        let time_str = entry.time.to_string();
        let day_of_week = entry.date.format("%A").to_string();

        // Pass day_of_week to editor for context, but LogEntry no longer stores it
        let result = editor::edit_existing_entry(
            &date_str,
            &time_str,
            &day_of_week,
            &entry.location,
            &entry.content,
            entry.tag.as_deref(),
        )?;

        if let Some((new_date_str, new_time_str, new_location, new_content, new_tag)) = result {
            // Parse the edited values
            let new_date: chrono::NaiveDate = new_date_str.parse()?;
            let new_time: chrono::NaiveTime = new_time_str.parse()?;

            // Update the entry keeping the same ID
            let updated_entry = models::LogEntry {
                id: entry.id.clone(),
                date: new_date,
                time: new_time,
                location: new_location,
                tag: new_tag,
                content: new_content,
            };

            // Update in database
            app.db.update_entry(&updated_entry)?;
            app.entries = app.db.get_entries_for_date(app.current_date)?;
        }

        app.mode = AppMode::DailyView;
        resume_tui(terminal)?;
    }
    Ok(())
}

fn suspend_tui<B: ratatui::backend::Backend + Write>(terminal: &mut Terminal<B>) -> Result<()> {
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;
    Ok(())
}

fn resume_tui<B: ratatui::backend::Backend + Write>(terminal: &mut Terminal<B>) -> Result<()> {
    enable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        EnterAlternateScreen,
        EnableMouseCapture
    )?;
    terminal.hide_cursor()?;
    terminal.clear()?;
    Ok(())
}
