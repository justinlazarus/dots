use crate::db::Database; // New import
use crate::summary::MonthlySummaries;
use anyhow::Result;
use chrono::{NaiveDate, NaiveTime};

#[derive(Debug, Clone)]
pub struct LogEntry {
    pub id: String,
    pub date: NaiveDate,
    pub time: NaiveTime,
    pub location: String,
    pub tag: Option<String>,
    // Optional title stored in YAML frontmatter
    pub title: Option<String>,
    pub content: String,
}

impl LogEntry {}

#[derive(Debug, Clone, PartialEq)]
pub enum AppMode {
    DailyView,
    // Removed QuickEntry/FullEntry/EditEntry — editor is invoked synchronously
    EntryView(usize),
    ConfirmDelete(usize),
    SelectEntry,
    // DaySearchView used for inline day highlighting
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

    // Was the current EntryView opened from the SelectEntry list? When true,
    // Esc from EntryView returns to SelectEntry instead of DailyView.
    pub return_to_selection: bool,

    // When a ConfirmDelete is requested from the SelectEntry mode this flag
    // distinguishes that origin so the post-delete flow returns to the
    // selection list instead of the entry view.
    pub confirm_from_selection: bool,
    /// When EntryView is opened from the selection list we save the index
    /// that was selected so we can restore it when returning to the list.
    pub prev_selected_entry_index: Option<usize>,

    // --- Tag State ---
    // (removed unused tag tracking fields)

    // --- UI State ---
    pub viewport_height: usize, // Track viewport height for page scrolling
    pub should_quit: bool,
    // Links extracted from the most recently-rendered entry view. When the
    // entry detail is rendered we populate this so key handlers can open a
    // link by index (e.g. press '1' to open the first link).
    pub last_rendered_links: Vec<String>,
    // Positions for the last rendered links (absolute terminal coordinates).
    // Each tuple: (link_index (0-based), row, start_col, end_col)
    pub last_rendered_link_positions: Vec<(usize, u16, u16, u16)>,
    // Last detail-area bounding box where links were rendered: (x, y, width, height)
    pub last_detail_area: Option<(u16, u16, u16, u16)>,
    // When true, mouse events are passed through to the terminal emulator
    // (we have called DisableMouseCapture). This allows native selection.
    pub mouse_passthrough_enabled: bool,
}

impl AppState {
    pub fn new(db: Database, initial_entries: Vec<LogEntry>) -> Self {
        Self {
            db,
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
            return_to_selection: false,
            confirm_from_selection: false,
            prev_selected_entry_index: None,
            viewport_height: 10, // Default, will be updated during render
            should_quit: false,
            last_rendered_links: Vec::new(),
            last_rendered_link_positions: Vec::new(),
            last_detail_area: None,
            // We never enable mouse capture; leave passthrough enabled so the
            // terminal emulator handles mouse selection and clicks.
            mouse_passthrough_enabled: true,
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
