use crate::models::AppState;
use chrono::NaiveDate;

/// Perform a search across all entries
/// Returns list of (date, entry_index) tuples for matching entries
pub fn search_entries(app: &AppState, query: &str) -> Vec<(NaiveDate, usize)> {
    // Use the database search method
    app.db.search_entries(query).unwrap_or_default()
}

// Tests disabled for now - need to be updated for database-backed search
// #[cfg(test)]
// mod tests {
//     use super::*;
//     use crate::models::LogEntry;
//     use chrono::{NaiveDate, NaiveTime};
//     use std::path::PathBuf;
//
//     #[test]
//     fn test_search_entries() {
//         // TODO: Update tests to use actual database
//     }
// }
