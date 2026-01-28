use crate::db::Database; // New import
use crate::summary::MonthlySummaries;
use anyhow::Result;
use chrono::{NaiveDate, NaiveTime};
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct LogEntry {
    pub id: String,
    pub date: NaiveDate,
    pub time: NaiveTime,
    pub location: String,
    pub tag: Option<String>,
    pub content: String,
}

impl LogEntry {
    pub fn new(
        date: NaiveDate,
        time: NaiveTime,
        // day_of_week removed; compute from date when needed
        location: String,
        content: String,
    ) -> Self {
        Self {
            id: ulid::Ulid::new().to_string(),
            date,
            time,
            location,
            tag: None,
            content,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum AppMode {
    DailyView,
    QuickEntry,
    FullEntry,
    EditEntry(usize),
    EntryView(usize),
    ConfirmDelete(usize),
    SelectEntry,
    SearchView,
    DaySearchView,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TagFilter {
    All,
    Tag(String),
    Untagged,
}

pub struct AppState {
    // --- Database Handle ---
    pub db: Database,

    // --- File Paths ---
    pub log_file_path: PathBuf,
    pub year: i32,

    // --- Current View State ---
    pub current_date: NaiveDate,
    /// Now only holds entries for the *currently viewed* day
    pub entries: Vec<LogEntry>,

    // --- Summaries (Still kept in memory for quick reference) ---
    pub monthly_summaries: MonthlySummaries,

    // --- UI/Interaction State ---
    pub mode: AppMode,
    pub scroll_offset: u16,
    pub selected_entry_index: usize,
    pub current_tag_filter: TagFilter,

    // --- Search State ---
    pub search_query: String,
    pub search_results: Vec<(NaiveDate, usize)>,
    pub day_search_query: String,

    // --- Tag State ---
    pub available_tags: Vec<(String, usize)>, // (tag, count) sorted by count desc
    pub untagged_count: usize,

    // --- UI State ---
    pub viewport_height: usize, // Track viewport height for page scrolling
    pub should_quit: bool,
}

impl AppState {
    pub fn new(
        db: Database,
        log_file_path: PathBuf,
        year: i32,
        initial_entries: Vec<LogEntry>,
    ) -> Self {
        Self {
            db,
            log_file_path,
            year,
            current_date: chrono::Local::now().date_naive(),
            entries: initial_entries,
            monthly_summaries: MonthlySummaries::new(),
            mode: AppMode::DailyView,

            scroll_offset: 0,
            selected_entry_index: 0,
            current_tag_filter: TagFilter::All,
            search_query: String::new(),
            search_results: Vec::new(),
            day_search_query: String::new(),
            available_tags: Vec::new(),
            untagged_count: 0,
            viewport_height: 10, // Default, will be updated during render
            should_quit: false,
        }
    }

    /// Refresh the local `entries` cache from the database
    pub fn refresh_current_day(&mut self) -> Result<()> {
        self.entries = self.db.get_entries_for_date(self.current_date)?;

        // No last_location field anymore; nothing to update here
        Ok(())
    }

    /// Navigate to a new date and load its data
    pub fn set_date(&mut self, date: NaiveDate) -> Result<()> {
        self.current_date = date;
        self.refresh_current_day()?;
        self.scroll_offset = 0;
        self.selected_entry_index = 0;
        Ok(())
    }

    pub fn get_filtered_entries(&self) -> Vec<LogEntry> {
        match &self.current_tag_filter {
            TagFilter::All => self.entries.clone(),
            TagFilter::Tag(tag) => self
                .entries
                .iter()
                .filter(|e| e.tag.as_ref() == Some(tag))
                .cloned()
                .collect(),
            TagFilter::Untagged => self
                .entries
                .iter()
                .filter(|e| e.tag.is_none())
                .cloned()
                .collect(),
        }
    }
}
