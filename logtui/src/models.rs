use chrono::{NaiveDate, NaiveTime};
use std::collections::HashMap;
use std::path::PathBuf;
use crate::summary::MonthlySummaries;

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
