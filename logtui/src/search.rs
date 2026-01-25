use crate::models::AppState;
use chrono::NaiveDate;

/// Perform a search across all entries
/// Returns list of (date, entry_index) tuples for matching entries
pub fn search_entries(app: &AppState, query: &str) -> Vec<(NaiveDate, usize)> {
    if query.is_empty() {
        return Vec::new();
    }

    let query_lower = query.to_lowercase();
    let mut results = Vec::new();

    // Get all dates sorted
    let mut dates: Vec<&NaiveDate> = app.entries.keys().collect();
    dates.sort();
    dates.reverse(); // Most recent first

    for date in dates {
        if let Some(entries) = app.entries.get(date) {
            for (idx, entry) in entries.iter().enumerate() {
                // Search in content, location, or date
                if entry.content.to_lowercase().contains(&query_lower)
                    || entry.location.to_lowercase().contains(&query_lower)
                {
                    results.push((*date, idx));
                }
            }
        }
    }

    results
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::LogEntry;
    use chrono::{NaiveDate, NaiveTime};
    use std::collections::HashMap;
    use std::path::PathBuf;

    #[test]
    fn test_search_entries() {
        let mut entries = HashMap::new();
        
        let date1 = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
        let time1 = NaiveTime::from_hms_opt(12, 0, 0).unwrap();
        let entry1 = LogEntry::new(
            date1,
            time1,
            "Thursday".to_string(),
            "Issaquah, WA".to_string(),
            "Working on the log TUI".to_string(),
        );

        let date2 = NaiveDate::from_ymd_opt(2026, 1, 2).unwrap();
        let time2 = NaiveTime::from_hms_opt(13, 0, 0).unwrap();
        let entry2 = LogEntry::new(
            date2,
            time2,
            "Friday".to_string(),
            "Seattle, WA".to_string(),
            "Went to the market".to_string(),
        );

        entries.insert(date1, vec![entry1]);
        entries.insert(date2, vec![entry2]);

        let app = AppState::new(PathBuf::from("test.md"), 2026, entries);

        // Search for "log"
        let results = search_entries(&app, "log");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].0, date1);

        // Search for "WA" (should match both locations)
        let results = search_entries(&app, "WA");
        assert_eq!(results.len(), 2);

        // Search for "market"
        let results = search_entries(&app, "market");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].0, date2);

        // Case insensitive search
        let results = search_entries(&app, "MARKET");
        assert_eq!(results.len(), 1);

        // No results
        let results = search_entries(&app, "xyz");
        assert_eq!(results.len(), 0);
    }
}
