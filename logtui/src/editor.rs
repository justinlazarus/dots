use anyhow::Context;
use anyhow::Result;
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
    _is_today: bool,
) -> Result<Option<(String, String, Option<String>)>> {
    // Create temp file with .md extension
    let mut temp_file = NamedTempFile::with_suffix(".md").context("Failed to create temp file")?;

    let now = Local::now();

    // Write YAML frontmatter
    writeln!(temp_file, "---")?;
    writeln!(temp_file, "date: {}", date.format("%Y-%m-%d"))?;
    writeln!(temp_file, "time: {}", now.time().format("%H:%M:%S"))?;
    // Write location even if empty; parser will accept empty location
    writeln!(temp_file, "location: {}", location.unwrap_or_default())?;
    writeln!(temp_file, "type: log")?;
    if let Some(tag) = default_tag {
        writeln!(temp_file, "tag: {}", tag)?;
    }
    writeln!(temp_file, "---")?;
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

    // Parse YAML frontmatter
    parse_yaml_frontmatter(&content)
}

/// Open external editor for editing an existing entry
/// Returns (date, time, day_of_week, location, content, tag) after editing, or None if cancelled
pub fn edit_existing_entry(
    date_str: &str,
    time_str: &str,
    _day_of_week: &str,
    location: &str,
    content: &str,
    tag: Option<&str>,
) -> Result<Option<(String, String, String, String, Option<String>)>> {
    // Create temp file with .md extension
    let mut temp_file = NamedTempFile::with_suffix(".md").context("Failed to create temp file")?;

    // Write YAML frontmatter
    writeln!(temp_file, "---")?;
    writeln!(temp_file, "date: {}", date_str)?;
    writeln!(temp_file, "time: {}", time_str)?;
    writeln!(temp_file, "location: {}", location)?;
    writeln!(temp_file, "type: log")?;
    if let Some(t) = tag {
        writeln!(temp_file, "tag: {}", t)?;
    }
    writeln!(temp_file, "---")?;
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

    // Parse YAML and return with original date/time/day
    if let Some((new_location, new_content, new_tag)) = parse_yaml_frontmatter(&edited_content)? {
        Ok(Some((
            date_str.to_string(),
            time_str.to_string(),
            new_location,
            new_content,
            new_tag,
        )))
    } else {
        Ok(None)
    }
}

/// Open external editor for editing a day's summary
/// Returns Some(text) if saved, None if cancelled
pub fn edit_summary(date: chrono::NaiveDate, current: &str) -> Result<Option<String>> {
    let mut temp_file = NamedTempFile::with_suffix(".md").context("Failed to create temp file")?;

    writeln!(temp_file, "# Summary for {}", date.format("%Y-%m-%d"))?;
    writeln!(temp_file)?;
    writeln!(temp_file, "{}", current)?;
    temp_file.flush()?;

    let temp_path = temp_file.path().to_path_buf();
    let editor = get_editor();
    let status = Command::new(&editor)
        .arg(&temp_path)
        .status()
        .with_context(|| format!("Failed to launch editor: {}", editor))?;

    if !status.success() {
        return Ok(None);
    }

    let content = std::fs::read_to_string(&temp_path).context("Failed to read temp file")?;
    // Return the whole file as the summary body (strip leading header line if present)
    let lines: Vec<&str> = content.lines().collect();
    let body = if !lines.is_empty() && lines[0].trim_start().starts_with('#') {
        lines
            .iter()
            .skip(1)
            .map(|s| *s)
            .collect::<Vec<&str>>()
            .join("\n")
            .trim()
            .to_string()
    } else {
        content.trim().to_string()
    };

    if body.is_empty() {
        Ok(None)
    } else {
        Ok(Some(body))
    }
}

/// Parse edited entry content including datetime
/// Returns (date, time, day_of_week, location, content, tag) if valid, None if cancelled
// Old header-based parsing helpers removed — we now use YAML frontmatter

/// Parse the content from the editor, extracting tag from header
/// Returns (location, content, tag) if valid, None if cancelled
fn parse_yaml_frontmatter(content: &str) -> Result<Option<(String, String, Option<String>)>> {
    let lines: Vec<&str> = content.lines().collect();

    // Find YAML frontmatter delimiters more robustly (trimmed)
    if lines.is_empty() {
        return Ok(None);
    }

    let start_idx_opt = lines.iter().position(|l| l.trim() == "---");
    // If no frontmatter start marker, treat whole file as content (no metadata)
    if start_idx_opt.is_none() {
        let content_str = content.trim().to_string();
        if content_str.is_empty() {
            return Ok(None);
        }
        return Ok(Some((String::new(), content_str, None)));
    }

    let start_idx = start_idx_opt.unwrap();
    // Find end marker after start
    let end_rel = lines
        .iter()
        .skip(start_idx + 1)
        .position(|l| l.trim() == "---");
    if end_rel.is_none() {
        return Ok(None);
    }
    let end_idx = start_idx + 1 + end_rel.unwrap();

    // Parse frontmatter
    let mut location: Option<String> = None;
    let mut tag: Option<String> = None;
    let mut entry_type: Option<String> = None;

    for line in &lines[start_idx + 1..end_idx] {
        if let Some(colon_pos) = line.find(':') {
            let key = line[..colon_pos].trim();
            let value = line[colon_pos + 1..].trim();

            match key {
                // Accept location even if empty string
                "location" => {
                    location = Some(value.to_string());
                }
                "tag" => {
                    if !value.is_empty() {
                        tag = Some(value.to_string());
                    }
                }
                "type" => {
                    if !value.is_empty() {
                        entry_type = Some(value.to_string());
                    }
                }
                "date" | "time" => {
                    // We read these but don't use them for new entries
                    // (we use current date/time instead)
                }
                _ => {}
            }
        }
    }

    // Get content after frontmatter
    let content_lines: Vec<&str> = lines.iter().skip(end_idx + 1).copied().collect();
    let content_str = content_lines.join("\n").trim().to_string();

    // Content may be empty when YAML frontmatter is present; accept empty content

    // Use empty string for missing location
    let final_location = location.unwrap_or_default();

    // Use type as tag if no explicit tag provided
    let final_tag = tag.or(entry_type);

    Ok(Some((final_location, content_str, final_tag)))
}

// Old header-based parsing helpers removed — we now use YAML frontmatter

// Summary editor removed — summary handling moved elsewhere

// old header-based tests removed — parsing now uses YAML frontmatter and should be tested elsewhere
