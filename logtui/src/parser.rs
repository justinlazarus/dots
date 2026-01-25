use crate::models::LogEntry;
use anyhow::{Context, Result};
use chrono::{Datelike, NaiveDate, NaiveTime};
use regex::Regex;
use std::collections::HashMap;

/// Parse the entire log file and return entries grouped by date
pub fn parse_log_file(content: &str, year: i32) -> Result<HashMap<NaiveDate, Vec<LogEntry>>> {
    let mut entries: HashMap<NaiveDate, Vec<LogEntry>> = HashMap::new();
    
    // Regex pattern: ## YYYY-MM-DD HH:MM:SS DayOfWeek - Location [#tag]
    let header_pattern = Regex::new(r"^## (\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) (\w+) - ([^#]+?)(?:\s*#(\w+).*)?$").unwrap();
    
    let lines: Vec<&str> = content.lines().collect();
    let mut i = 0;
    
    while i < lines.len() {
        let line = lines[i].trim();
        
        // Check if this line is an entry header
        if let Some(captures) = header_pattern.captures(line) {
            let date_str = &captures[1];
            let time_str = &captures[2];
            let day_of_week = captures[3].to_string();
            let location = captures[4].trim().to_string();
            let tag = captures.get(5).map(|m| m.as_str().to_string());
            
            // Parse date and time
            let date = NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
                .with_context(|| format!("Failed to parse date: {}", date_str))?;
            let time = NaiveTime::parse_from_str(time_str, "%H:%M:%S")
                .with_context(|| format!("Failed to parse time: {}", time_str))?;
            
            // Validate year matches file year
            if date.year() != year {
                eprintln!("Warning: Entry date {} doesn't match file year {}, skipping", date, year);
                i += 1;
                continue;
            }
            
            // Collect content lines until next header or EOF
            let mut content_lines = Vec::new();
            i += 1;
            
            while i < lines.len() {
                let content_line = lines[i];
                
                // Check if we've hit the next header
                if header_pattern.is_match(content_line.trim()) {
                    break;
                }
                
                content_lines.push(content_line);
                i += 1;
            }
            
            // Join content lines and trim
            let content = content_lines.join("\n").trim().to_string();
            
            // Create entry
            let mut entry = LogEntry::new(date, time, day_of_week, location, content);
            entry.tag = tag;
            
            // Add to entries map
            entries.entry(date).or_insert_with(Vec::new).push(entry);
        } else {
            i += 1;
        }
    }
    
    // Sort entries within each date by time
    for entry_list in entries.values_mut() {
        entry_list.sort_by_key(|e| e.time);
    }
    
    Ok(entries)
}

/// Serialize entries back to markdown format
pub fn serialize_entries(entries: &HashMap<NaiveDate, Vec<LogEntry>>, year: i32) -> String {
    let mut output = format!("# {} Log\n\n", year);
    
    // Get all dates and sort them
    let mut dates: Vec<&NaiveDate> = entries.keys().collect();
    dates.sort();
    
    for date in dates {
        if let Some(entry_list) = entries.get(date) {
            for entry in entry_list {
                // Format: ## YYYY-MM-DD HH:MM:SS DayOfWeek - Location [#tag]
                let header = if let Some(tag) = &entry.tag {
                    format!(
                        "## {} {} {} - {} #{}",
                        entry.date.format("%Y-%m-%d"),
                        entry.time.format("%H:%M:%S"),
                        entry.day_of_week,
                        entry.location,
                        tag
                    )
                } else {
                    format!(
                        "## {} {} {} - {}",
                        entry.date.format("%Y-%m-%d"),
                        entry.time.format("%H:%M:%S"),
                        entry.day_of_week,
                        entry.location
                    )
                };
                
                output.push_str(&header);
                output.push_str("\n\n");
                output.push_str(&entry.content);
                output.push_str("\n\n");
            }
        }
    }
    
    output
}

/// Add a new entry to the entries map and return the updated serialized content
pub fn add_entry(
    entries: &mut HashMap<NaiveDate, Vec<LogEntry>>,
    entry: LogEntry,
    year: i32,
) -> String {
    let date = entry.date;
    entries.entry(date).or_insert_with(Vec::new).push(entry);
    
    // Sort entries for this date by time
    if let Some(entry_list) = entries.get_mut(&date) {
        entry_list.sort_by_key(|e| e.time);
    }
    
    serialize_entries(entries, year)
}

/// Update an existing entry and return the updated serialized content
pub fn update_entry(
    entries: &mut HashMap<NaiveDate, Vec<LogEntry>>,
    date: NaiveDate,
    index: usize,
    updated_entry: LogEntry,
    year: i32,
) -> Result<String> {
    let entry_list = entries
        .get_mut(&date)
        .context("No entries found for this date")?;
    
    if index >= entry_list.len() {
        anyhow::bail!("Entry index out of bounds");
    }
    
    entry_list[index] = updated_entry;
    
    // Re-sort entries by time
    entry_list.sort_by_key(|e| e.time);
    
    Ok(serialize_entries(entries, year))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_entry() {
        let content = r#"# 2026 Log

## 2026-01-01 12:31:14 Thursday - Rancho Mirage, CA

This is a test entry.
"#;
        
        let entries = parse_log_file(content, 2026).unwrap();
        assert_eq!(entries.len(), 1);
        
        let date = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
        let entry_list = entries.get(&date).unwrap();
        assert_eq!(entry_list.len(), 1);
        
        let entry = &entry_list[0];
        assert_eq!(entry.day_of_week, "Thursday");
        assert_eq!(entry.location, "Rancho Mirage, CA");
        assert_eq!(entry.content, "This is a test entry.");
    }

    #[test]
    fn test_serialize_entry() {
        let mut entries = HashMap::new();
        let date = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
        let time = NaiveTime::from_hms_opt(12, 31, 14).unwrap();
        
        let entry = LogEntry::new(
            date,
            time,
            "Thursday".to_string(),
            "Rancho Mirage, CA".to_string(),
            "This is a test entry.".to_string(),
        );
        
        entries.insert(date, vec![entry]);
        
        let serialized = serialize_entries(&entries, 2026);
        assert!(serialized.contains("# 2026 Log"));
        assert!(serialized.contains("## 2026-01-01 12:31:14 Thursday - Rancho Mirage, CA"));
        assert!(serialized.contains("This is a test entry."));
    }
}
