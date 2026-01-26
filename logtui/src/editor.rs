use anyhow::{Context, Result};
use chrono::Local;
use std::env;
use std::fs;
use std::io::Write;
use std::process::Command;
use tempfile::NamedTempFile;

/// Get the editor command from environment or default to nvim
fn get_editor() -> String {
    let editor = env::var("EDITOR").unwrap_or_else(|_| "nvim".to_string());
    
    // Handle common variations
    match editor.as_str() {
        "neovim" => "nvim".to_string(),
        "vim" => "vim".to_string(),
        "vi" => "vi".to_string(),
        _ => editor,
    }
}

/// Open external editor for creating a new entry
/// Returns (location, content, tag) written by the user, or None if cancelled
pub fn edit_new_entry(
    location: Option<String>,
    default_tag: Option<String>,
    date: chrono::NaiveDate,
    is_today: bool,
) -> Result<Option<(String, String, Option<String>)>> {
    let header_base = if is_today {
        // Include time for today
        let now = Local::now();
        format!(
            "## {} {} {} - ",
            date.format("%Y-%m-%d"),
            now.time().format("%H:%M:%S"),
            date.format("%A")
        )
    } else {
        // Omit time for retrospective entries
        let day_of_week = date.format("%A").to_string();
        format!(
            "## {} {} - ",
            date.format("%Y-%m-%d"),
            day_of_week
        )
    };

    // Create temp file with .md extension
    let mut temp_file = NamedTempFile::with_suffix(".md").context("Failed to create temp file")?;
    
    // Build header with location and optional tag
    let tag_suffix = default_tag.as_ref().map(|t| format!(" #{}", t)).unwrap_or_default();
    
    // Write header with location if provided, otherwise empty location for user to fill
    if let Some(loc) = location.as_ref() {
        writeln!(temp_file, "{}{}{}", header_base, loc, tag_suffix)?;
    } else {
        writeln!(temp_file, "{}<LOCATION>{}", header_base, tag_suffix)?;
    }
    
    writeln!(temp_file)?;
    writeln!(temp_file, "# Write your log entry below this line")?;
    writeln!(temp_file, "# Lines starting with # will be ignored")?;
    writeln!(temp_file)?;
    
    temp_file.flush()?;
    let temp_path = temp_file.path().to_path_buf();

    // Launch editor
    let editor = get_editor();
    let status = Command::new(&editor)
        .arg(&temp_path)
        .status()
        .with_context(|| format!("Failed to launch editor: {}", editor))?;

    if !status.success() {
        return Ok(None);
    }

    // Read back the content
    let content = fs::read_to_string(&temp_path).context("Failed to read temp file")?;
    
    // Parse the header and content
    parse_edited_content_with_tag(&content, location.is_none())
}

/// Open external editor for editing an existing entry
/// Returns (date, time, day_of_week, location, content, tag) after editing, or None if cancelled
pub fn edit_existing_entry(
    date_str: &str,
    time_str: &str,
    day_of_week: &str,
    location: &str,
    content: &str,
    tag: Option<&str>,
) -> Result<Option<(String, String, String, String, String, Option<String>)>> {
    let tag_suffix = tag.map(|t| format!(" #{}", t)).unwrap_or_default();
    let header = format!("## {} {} {} - {}{}", date_str, time_str, day_of_week, location, tag_suffix);

    // Create temp file with .md extension
    let mut temp_file = NamedTempFile::with_suffix(".md").context("Failed to create temp file")?;
    writeln!(temp_file, "{}", header)?;
    writeln!(temp_file)?;
    writeln!(temp_file, "{}", content)?;
    
    temp_file.flush()?;
    let temp_path = temp_file.path().to_path_buf();

    // Launch editor
    let editor = get_editor();
    let status = Command::new(&editor)
        .arg(&temp_path)
        .status()
        .with_context(|| format!("Failed to launch editor: {}", editor))?;

    if !status.success() {
        return Ok(None);
    }

    // Read back the content
    let edited_content = fs::read_to_string(&temp_path).context("Failed to read temp file")?;
    
    // Parse the edited content including datetime
    parse_edited_entry_with_datetime(&edited_content)
}

/// Parse edited entry content including datetime
/// Returns (date, time, day_of_week, location, content, tag) if valid, None if cancelled
fn parse_edited_entry_with_datetime(content: &str) -> Result<Option<(String, String, String, String, String, Option<String>)>> {
    use regex::Regex;
    
    let lines: Vec<&str> = content.lines().collect();
    
    if lines.is_empty() {
        return Ok(None);
    }

    // First line should be the header: ## YYYY-MM-DD [HH:MM:SS] DayOfWeek - Location #tag
    // Time is optional - represents retrospective entry if omitted
    let header_line = lines[0];
    
    // Extract datetime, day of week, location, and tag from header
    let header_re = Regex::new(r"^##\s+(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}:\d{2}:\d{2}))?\s+(\w+)\s+-\s+(.+?)(?:\s+#(\w+))?$").unwrap();
    
    let captures = header_re.captures(header_line);
    if captures.is_none() {
        return Ok(None);
    }
    
    let caps = captures.unwrap();
    let date = caps.get(1).unwrap().as_str().to_string();
    let time = caps.get(2)
        .map(|m| m.as_str().to_string())
        .unwrap_or_else(|| "00:00:00".to_string());
    let day_of_week = caps.get(3).unwrap().as_str().to_string();
    let location = caps.get(4).unwrap().as_str().trim().to_string();
    let tag = caps.get(5).map(|m| m.as_str().to_string());

    // Collect content lines (skip header and comment lines)
    let mut content_lines = Vec::new();
    let mut in_content = false;

    for line in lines.iter().skip(1) {
        if line.trim().is_empty() && !in_content {
            continue;
        }
        
        // Skip comment lines
        if line.trim().starts_with('#') {
            continue;
        }
        
        in_content = true;
        content_lines.push(*line);
    }

    let content_str = content_lines.join("\n").trim().to_string();
    
    // If content is empty, consider it cancelled
    if content_str.is_empty() {
        return Ok(None);
    }

    Ok(Some((date, time, day_of_week, location, content_str, tag)))
}

/// Parse the content from the editor, extracting tag from header
/// Returns (location, content, tag) if valid, None if cancelled
fn parse_edited_content_with_tag(content: &str, location_needed: bool) -> Result<Option<(String, String, Option<String>)>> {
    use regex::Regex;
    
    let lines: Vec<&str> = content.lines().collect();
    
    if lines.is_empty() {
        return Ok(None);
    }

    // First line should be the header
    let header_line = lines[0];
    
    // Extract tag from header (first #word pattern)
    let tag_re = Regex::new(r"#(\w+)").unwrap();
    let tag = tag_re.captures(header_line).map(|c| c.get(1).unwrap().as_str().to_string());
    
    // Extract location from header (between " - " and optional tag)
    let location = if let Some(pos) = header_line.rfind(" - ") {
        let after_dash = &header_line[pos + 3..];
        // Remove tag from location if present
        let loc = if let Some(tag_pos) = after_dash.find('#') {
            after_dash[..tag_pos].trim()
        } else {
            after_dash.trim()
        };
        
        if location_needed && loc == "<LOCATION>" {
            // User didn't fill in location
            return Ok(None);
        }
        loc.to_string()
    } else {
        return Ok(None);
    };

    // Collect content lines (skip header and comment lines)
    let mut content_lines = Vec::new();
    let mut in_content = false;

    for line in lines.iter().skip(1) {
        if line.trim().is_empty() && !in_content {
            continue;
        }
        
        // Skip comment lines
        if line.trim().starts_with('#') {
            continue;
        }
        
        in_content = true;
        content_lines.push(*line);
    }

    let content_str = content_lines.join("\n").trim().to_string();
    
    // If content is empty, consider it cancelled
    if content_str.is_empty() {
        return Ok(None);
    }

    Ok(Some((location, content_str, tag)))
}

/// Open external editor for editing a daily summary
/// Returns the edited summary text, or None if cancelled
pub fn edit_summary(date_str: &str, current_summary: &str) -> Result<Option<String>> {
    // Create temp file with .md extension
    let mut temp_file = NamedTempFile::with_suffix(".md").context("Failed to create temp file")?;
    
    // Write header and current summary
    writeln!(temp_file, "# Summary for {}", date_str)?;
    writeln!(temp_file, "# Write a brief summary of the day below")?;
    writeln!(temp_file, "# Lines starting with # will be ignored")?;
    writeln!(temp_file)?;
    writeln!(temp_file, "{}", current_summary)?;
    
    temp_file.flush()?;
    let temp_path = temp_file.path().to_path_buf();

    // Launch editor
    let editor = get_editor();
    let status = Command::new(&editor)
        .arg(&temp_path)
        .status()
        .with_context(|| format!("Failed to launch editor: {}", editor))?;

    if !status.success() {
        return Ok(None);
    }

    // Read back the content
    let content = fs::read_to_string(&temp_path).context("Failed to read temp file")?;
    
    // Parse the content - skip comment lines
    let mut content_lines = Vec::new();
    for line in content.lines() {
        if line.trim().starts_with('#') {
            continue;
        }
        content_lines.push(line);
    }
    
    let summary = content_lines.join("\n").trim().to_string();
    
    Ok(Some(summary))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_edited_content_with_location() {
        let content = r#"## 2026-01-25 14:30:00 Sunday - Issaquah, WA

This is my log entry.
It has multiple lines.
"#;
        
        let result = parse_edited_content_with_tag(content, false).unwrap();
        assert!(result.is_some());
        
        let (location, text, tag) = result.unwrap();
        assert_eq!(location, "Issaquah, WA");
        assert!(text.contains("This is my log entry"));
        assert!(text.contains("multiple lines"));
        assert!(tag.is_none());
    }

    #[test]
    fn test_parse_edited_content_with_tag() {
        let content = r#"## 2026-01-25 14:30:00 Sunday - Issaquah, WA #log

This is my log entry.
"#;
        
        let result = parse_edited_content_with_tag(content, false).unwrap();
        assert!(result.is_some());
        
        let (location, text, tag) = result.unwrap();
        assert_eq!(location, "Issaquah, WA");
        assert!(text.contains("This is my log entry"));
        assert_eq!(tag, Some("log".to_string()));
    }

    #[test]
    fn test_parse_edited_content_filters_comments() {
        let content = r#"## 2026-01-25 14:30:00 Sunday - Issaquah, WA

# This is a comment
This is actual content.
# Another comment
More content.
"#;
        
        let result = parse_edited_content_with_tag(content, false).unwrap();
        assert!(result.is_some());
        
        let (_, text, _) = result.unwrap();
        assert!(!text.contains("# This is a comment"));
        assert!(text.contains("This is actual content"));
        assert!(text.contains("More content"));
    }

    #[test]
    fn test_parse_empty_content() {
        let content = r#"## 2026-01-25 14:30:00 Sunday - Issaquah, WA

# Just comments
# Nothing else
"#;
        
        let result = parse_edited_content_with_tag(content, false).unwrap();
        assert!(result.is_none());
    }
}
