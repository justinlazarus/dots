use chrono::{NaiveDate, NaiveTime};
use std::collections::HashMap;
use std::path::PathBuf;
use crate::summary::MonthlySummaries;
use anyhow::Result;

#[derive(Debug, Clone)]
pub struct LogEntry {
    pub date: NaiveDate,
    pub time: NaiveTime,
    pub day_of_week: String,
    pub location: String,
    pub tag: Option<String>,
    pub content: String,
}

impl LogEntry {
    pub fn new(
        date: NaiveDate,
        time: NaiveTime,
        day_of_week: String,
        location: String,
        content: String,
    ) -> Self {
        Self {
            date,
            time,
            day_of_week,
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
    EditEntry(usize),      // index of entry being edited on current day
    SelectEntry,            // selecting which entry to edit when multiple exist
    CalendarView,
    SearchView,             // global search across all days
    DaySearchView,          // search/highlight within current day only
    JumpToDate,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TagFilter {
    All,
    Tag(String),
    Untagged,
}

impl TagFilter {
    pub fn as_display_string(&self) -> String {
        match self {
            TagFilter::All => "all".to_string(),
            TagFilter::Tag(s) => format!("#{}", s),
            TagFilter::Untagged => "untagged".to_string(),
        }
    }
}

pub struct AppState {
    pub current_date: NaiveDate,
    pub entries: HashMap<NaiveDate, Vec<LogEntry>>,
    pub mode: AppMode,
    pub last_location: Option<String>,
    pub selected_entry_index: usize,
    pub search_query: String,
    pub search_results: Vec<(NaiveDate, usize)>,  // (date, entry_index)
    pub day_search_query: String,  // search query for highlighting current day
    pub log_file_path: PathBuf,
    pub year: i32,
    pub should_quit: bool,
    pub calendar_selected_date: NaiveDate,
    pub jump_input: String,
    pub location_input: String,
    pub scroll_offset: usize,
    pub current_tag_filter: TagFilter,
    pub available_tags: Vec<(String, usize)>,  // (tag, count) sorted by count desc
    pub untagged_count: usize,
    pub monthly_summaries: MonthlySummaries,  // daily summaries from summary file
    pub viewport_height: usize,  // Track viewport height for page scrolling
}

impl AppState {
    pub fn new(log_file_path: PathBuf, year: i32, entries: HashMap<NaiveDate, Vec<LogEntry>>) -> Self {
        // Extract last location from most recent entry
        let last_location = entries
            .values()
            .flatten()
            .max_by_key(|e| (e.date, e.time))
            .map(|e| e.location.clone());

        let current_date = chrono::Local::now().date_naive();

        Self {
            current_date,
            entries,
            mode: AppMode::DailyView,
            last_location,
            selected_entry_index: 0,
            search_query: String::new(),
            search_results: Vec::new(),
            day_search_query: String::new(),
            log_file_path,
            year,
            should_quit: false,
            calendar_selected_date: current_date,
            jump_input: String::new(),
            location_input: String::new(),
            scroll_offset: 0,
            current_tag_filter: TagFilter::All,
            available_tags: Vec::new(),
            untagged_count: 0,
            monthly_summaries: MonthlySummaries::new(),
            viewport_height: 10, // Default, will be updated during render
        }
    }

    pub fn get_entries_for_date(&self, date: &NaiveDate) -> Vec<LogEntry> {
        self.entries
            .get(date)
            .cloned()
            .unwrap_or_default()
    }

    pub fn prev_day(&mut self) {
        self.current_date = self.current_date.pred_opt().unwrap_or(self.current_date);
    }

    pub fn next_day(&mut self) {
        self.current_date = self.current_date.succ_opt().unwrap_or(self.current_date);
    }

    pub fn jump_to_today(&mut self) {
        self.current_date = chrono::Local::now().date_naive();
    }

    pub fn jump_to_next_month(&mut self) -> Option<i32> {
        use chrono::Datelike;
        let current_year = self.current_date.year();
        let current_month = self.current_date.month();
        
        // Calculate next month
        let (next_year, next_month) = if current_month == 12 {
            (current_year + 1, 1)
        } else {
            (current_year, current_month + 1)
        };
        
        // Jump to first day of next month
        if let Some(new_date) = NaiveDate::from_ymd_opt(next_year, next_month, 1) {
            self.current_date = new_date;
            
            // Return new year if year boundary was crossed
            if next_year != current_year {
                return Some(next_year);
            }
        }
        
        None
    }

    pub fn jump_to_prev_month(&mut self) -> Option<i32> {
        use chrono::Datelike;
        let current_year = self.current_date.year();
        let current_month = self.current_date.month();
        
        // Calculate previous month
        let (prev_year, prev_month) = if current_month == 1 {
            (current_year - 1, 12)
        } else {
            (current_year, current_month - 1)
        };
        
        // Jump to first day of previous month
        if let Some(new_date) = NaiveDate::from_ymd_opt(prev_year, prev_month, 1) {
            self.current_date = new_date;
            
            // Return new year if year boundary was crossed
            if prev_year != current_year {
                return Some(prev_year);
            }
        }
        
        None
    }

    /// Reload app state from a different year's log file
    /// Creates the file if it doesn't exist and shows empty state
    pub fn reload_from_year(&mut self, new_year: i32) -> Result<()> {
        // Find or create the log file for the new year
        let new_log_path = crate::storage::find_log_file_for_year(&self.log_file_path, new_year)?;
        
        // Load entries from new year (will be empty if newly created)
        let content = crate::storage::read_log_file(&new_log_path)?;
        let entries = crate::parser::parse_log_file(&content, new_year)?;
        
        // Load summaries from new year (will be empty if file doesn't exist)
        let summary_content = crate::storage::read_summary_file(&new_log_path)?;
        let monthly_summaries = crate::summary::parse_summary_file(&summary_content, new_year)?;
        
        // Update app state
        self.log_file_path = new_log_path;
        self.year = new_year;
        self.entries = entries;
        self.monthly_summaries = monthly_summaries;
        
        // Update last location from new entries (or keep current if no entries)
        let new_last_location = self.entries
            .values()
            .flatten()
            .max_by_key(|e| (e.date, e.time))
            .map(|e| e.location.clone());
        
        if new_last_location.is_some() {
            self.last_location = new_last_location;
        }
        // If no entries in new year, keep the last location from previous year
        
        // Reset state
        self.scroll_offset = 0;
        self.day_search_query.clear();
        
        Ok(())
    }

    pub fn has_entries_on_date(&self, date: &NaiveDate) -> bool {
        self.entries.contains_key(date)
    }

    pub fn get_filtered_entries_for_date(&self, date: &NaiveDate) -> Vec<LogEntry> {
        let all_entries = self.get_entries_for_date(date);
        
        match &self.current_tag_filter {
            TagFilter::All => all_entries,
            TagFilter::Tag(tag) => all_entries
                .into_iter()
                .filter(|e| e.tag.as_ref() == Some(tag))
                .collect(),
            TagFilter::Untagged => all_entries
                .into_iter()
                .filter(|e| e.tag.is_none())
                .collect(),
        }
    }
}
