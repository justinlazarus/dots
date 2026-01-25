mod calendar;
mod editor;
mod models;
mod parser;
mod search;
mod storage;
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

    // Initialize app state
    let mut app = AppState::new(log_path, year, entries);
    
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
        b.1.cmp(&a.1)  // Count descending
            .then_with(|| a.0.cmp(&b.0))  // Then alphabetically
    });
    
    // Find smart default (most common tag, prefer #log on tie)
    let default_filter = if let Some((first_tag, first_count)) = tags.first() {
        // Check for ties with same count as first
        let tied_tags: Vec<&String> = tags.iter()
            .filter(|(_, count)| *count == *first_count)
            .map(|(tag, _)| tag)
            .collect();
        
        if tied_tags.contains(&&"log".to_string()) {
            TagFilter::Tag("log".to_string())
        } else {
            TagFilter::Tag(first_tag.clone())
        }
    } else if untagged_count > 0 {
        TagFilter::Untagged
    } else {
        TagFilter::All
    };
    
    app.available_tags = tags;
    app.untagged_count = untagged_count;
    app.current_tag_filter = default_filter;
}

enum Direction {
    Next,
    Prev,
}

fn cycle_tag_filter(app: &mut AppState, direction: Direction) {
    // Build filter list: tags by count, untagged (if any), all
    let mut filters: Vec<TagFilter> = Vec::new();
    
    // Add all tags (already sorted by count)
    for (tag, _) in &app.available_tags {
        filters.push(TagFilter::Tag(tag.clone()));
    }
    
    // Add untagged if present
    if app.untagged_count > 0 {
        filters.push(TagFilter::Untagged);
    }
    
    // Add "all" at the end
    filters.push(TagFilter::All);
    
    if filters.is_empty() {
        return; // No filters available
    }
    
    // Find current position
    let current_idx = filters.iter()
        .position(|f| f == &app.current_tag_filter)
        .unwrap_or(0);
    
    // Calculate next position
    let new_idx = match direction {
        Direction::Next => (current_idx + 1) % filters.len(),
        Direction::Prev => (current_idx + filters.len() - 1) % filters.len(),
    };
    
    app.current_tag_filter = filters[new_idx].clone();
    app.scroll_offset = 0;  // Reset scroll when filtering
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
        AppMode::CalendarView => handle_calendar_keys(app, key),
        AppMode::SearchView => handle_search_keys(app, key, modifiers),
        AppMode::DaySearchView => handle_day_search_keys(app, key),
        AppMode::JumpToDate => handle_jump_to_date_keys(app, key),
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
        KeyCode::Char('k') => {
            app.prev_day();
            app.scroll_offset = 0;
            app.day_search_query.clear();
            update_tag_state(app);
        }
        KeyCode::Char('j') => {
            app.next_day();
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
        KeyCode::Char('c') => {
            app.calendar_selected_date = app.current_date;
            app.mode = AppMode::CalendarView;
        }
        KeyCode::Char('/') => {
            // Day search with highlighting
            app.day_search_query.clear();
            app.mode = AppMode::DaySearchView;
        }
        KeyCode::Char(':') => {
            app.jump_input.clear();
            app.mode = AppMode::JumpToDate;
        }
        KeyCode::Char('n') => {
            // Quick entry with last location
            handle_new_entry(app, true, terminal)?;
        }
        KeyCode::Char('N') => {
            // Full entry - prompt for location
            handle_new_entry(app, false, terminal)?;
        }
        KeyCode::Char('i') => {
            // Edit entry
            handle_edit_entry(app, terminal)?;
        }
        KeyCode::Char('d') => {
            // Scroll down (Ctrl+d handled separately)
            app.scroll_offset = app.scroll_offset.saturating_add(1);
        }
        KeyCode::Char('u') => {
            // Scroll up (Ctrl+u handled separately)
            app.scroll_offset = app.scroll_offset.saturating_sub(1);
        }
        KeyCode::Down => {
            app.scroll_offset = app.scroll_offset.saturating_add(1);
        }
        KeyCode::Up => {
            app.scroll_offset = app.scroll_offset.saturating_sub(1);
        }
        KeyCode::PageDown => {
            app.scroll_offset = app.scroll_offset.saturating_add(10);
        }
        KeyCode::PageUp => {
            app.scroll_offset = app.scroll_offset.saturating_sub(10);
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
            if app.selected_entry_index + 1 < entries.len() {
                app.selected_entry_index += 1;
            }
        }
        KeyCode::Char('k') | KeyCode::Up => {
            if app.selected_entry_index > 0 {
                app.selected_entry_index -= 1;
            }
        }
        KeyCode::Enter => {
            // Edit the selected entry
            let idx = app.selected_entry_index;
            let entries = app.get_entries_for_date(&app.current_date);
            
            if let Some(entry) = entries.get(idx) {
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
                
                if let Some((location, content, tag)) = result {
                    // Update entry
                    let mut updated_entry = entry.clone();
                    updated_entry.location = location.clone();
                    updated_entry.content = content;
                    updated_entry.tag = tag;
                    
                    let serialized = parser::update_entry(
                        &mut app.entries,
                        app.current_date,
                        idx,
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
        _ => {}
    }
    Ok(())
}

fn handle_calendar_keys(app: &mut AppState, key: KeyCode) -> Result<()> {
    match key {
        KeyCode::Esc => {
            app.mode = AppMode::DailyView;
        }
        KeyCode::Char('h') | KeyCode::Left => {
            app.calendar_selected_date = calendar::navigate_calendar(
                app.calendar_selected_date,
                calendar::CalendarDirection::Left,
                app.year,
            );
        }
        KeyCode::Char('l') | KeyCode::Right => {
            app.calendar_selected_date = calendar::navigate_calendar(
                app.calendar_selected_date,
                calendar::CalendarDirection::Right,
                app.year,
            );
        }
        KeyCode::Char('j') | KeyCode::Down => {
            app.calendar_selected_date = calendar::navigate_calendar(
                app.calendar_selected_date,
                calendar::CalendarDirection::Down,
                app.year,
            );
        }
        KeyCode::Char('k') | KeyCode::Up => {
            app.calendar_selected_date = calendar::navigate_calendar(
                app.calendar_selected_date,
                calendar::CalendarDirection::Up,
                app.year,
            );
        }
        KeyCode::Enter => {
            app.current_date = app.calendar_selected_date;
            app.day_search_query.clear();
            app.mode = AppMode::DailyView;
            update_tag_state(app);
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

fn handle_jump_to_date_keys(app: &mut AppState, key: KeyCode) -> Result<()> {
    match key {
        KeyCode::Esc => {
            app.mode = AppMode::DailyView;
        }
        KeyCode::Char(c) => {
            app.jump_input.push(c);
        }
        KeyCode::Backspace => {
            app.jump_input.pop();
        }
        KeyCode::Enter => {
            // Try to parse the date
            if let Ok(date) = NaiveDate::parse_from_str(&app.jump_input, "%Y-%m-%d") {
                if date.year() == app.year {
                    app.current_date = date;
                }
            }
            app.day_search_query.clear();
            app.mode = AppMode::DailyView;
            update_tag_state(app);
        }
        _ => {}
    }
    Ok(())
}

fn handle_new_entry<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    use_last_location: bool,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    // Determine location
    let location = if use_last_location {
        app.last_location.clone()
    } else {
        None
    };
    
    // Determine default tag based on current filter
    let default_tag = match &app.current_tag_filter {
        TagFilter::Tag(tag) => Some(tag.clone()),
        TagFilter::Untagged => Some("log".to_string()),
        TagFilter::All => Some("log".to_string()),
    };

    // Suspend TUI and launch editor
    suspend_tui(terminal)?;
    
    let result = editor::edit_new_entry(location, default_tag)?;
    
    resume_tui(terminal)?;

    if let Some((location, content, tag)) = result {
        // Create new entry
        let now = Local::now();
        let mut entry = models::LogEntry::new(
            now.date_naive(),
            now.time(),
            now.format("%A").to_string(),
            location.clone(),
            content,
        );
        entry.tag = tag;

        // Add to entries and serialize
        let serialized = parser::add_entry(&mut app.entries, entry, app.year);
        storage::write_log_file(&app.log_file_path, &serialized)?;
        
        app.last_location = Some(location);
        app.current_date = now.date_naive();
        
        // Update tag state after adding new entry
        update_tag_state(app);
    }

    Ok(())
}

fn handle_edit_entry<B: ratatui::backend::Backend + Write>(
    app: &mut AppState,
    terminal: &mut Terminal<B>,
) -> Result<()> {
    let entries = app.get_entries_for_date(&app.current_date);

    if entries.is_empty() {
        // No entries to edit
        return Ok(());
    }

    if entries.len() == 1 {
        // Only one entry, edit it directly
        let entry = &entries[0];
        let date_str = entry.date.format("%Y-%m-%d").to_string();
        let time_str = entry.time.format("%H:%M:%S").to_string();
        
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
        
        if let Some((location, content, tag)) = result {
            let mut updated_entry = entry.clone();
            updated_entry.location = location.clone();
            updated_entry.content = content;
            updated_entry.tag = tag;
            
            let serialized = parser::update_entry(
                &mut app.entries,
                app.current_date,
                0,
                updated_entry,
                app.year,
            )?;
            
            storage::write_log_file(&app.log_file_path, &serialized)?;
            app.last_location = Some(location);
            update_tag_state(app);
        }
    } else {
        // Multiple entries, show selection UI
        app.selected_entry_index = 0;
        app.mode = AppMode::SelectEntry;
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
