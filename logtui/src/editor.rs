use anyhow::Context;
use anyhow::Result;
use chrono::Local;
use std::env;
use std::fs;
use std::io::Write;
use std::process::Command;
use tempfile::NamedTempFile;

/// Get the editor command from environment or default to nvim
pub fn get_editor() -> String {
    let editor = env::var("EDITOR").unwrap_or_else(|_| "nvim".to_string());

    // Handle common variations
    match editor.as_str() {
        "neovim" => "nvim".to_string(),
        "vim" => "vim".to_string(),
        "vi" => "vi".to_string(),
        _ => editor,
    }
}

// Helper to YAML-quote a value when necessary. Placed at module scope so both
// edit_new_entry and edit_existing_entry can reuse it.
fn yaml_quote(s: &str) -> String {
    if s.is_empty() {
        return String::new();
    }
    // If value contains characters that require quoting, wrap in double quotes
    if s.starts_with(' ') || s.ends_with(' ') || s.contains(':') || s.contains('"') {
        let escaped = s.replace('\\', "\\\\").replace('"', "\\\"");
        return format!("\"{}\"", escaped);
    }
    s.to_string()
}

/// Open external editor for creating a new entry
/// Returns (location, content, tag, title) written by the user, or None if cancelled
pub fn edit_new_entry(
    location: Option<String>,
    default_tag: Option<String>,
    date: chrono::NaiveDate,
    _is_today: bool,
) -> Result<
    Option<(
        String,
        String,
        String,
        String,
        Option<String>,
        Option<String>,
    )>,
> {
    // Create temp file with .md extension
    let mut temp_file = NamedTempFile::with_suffix(".md").context("Failed to create temp file")?;

    let now = Local::now();

    // Helper to YAML-quote a value when necessary
    fn yaml_quote(s: &str) -> String {
        if s.is_empty() {
            return String::new();
        }
        // If value contains characters that require quoting, wrap in double quotes
        if s.starts_with(' ') || s.ends_with(' ') || s.contains(':') || s.contains('"') {
            let escaped = s.replace('\\', "\\\\").replace('"', "\\\"");
            return format!("\"{}\"", escaped);
        }
        s.to_string()
    }

    // Write YAML frontmatter
    writeln!(temp_file, "---")?;
    writeln!(temp_file, "date: {}", date.format("%Y-%m-%d"))?;
    writeln!(temp_file, "time: {}", now.time().format("%H:%M:%S"))?;
    // Title field for explicit title in frontmatter (empty by default)
    writeln!(temp_file, "title: {}", yaml_quote(""))?;
    // Write location even if empty; parser will accept empty location
    writeln!(
        temp_file,
        "location: {}",
        yaml_quote(&location.unwrap_or_default())
    )?;
    // Always include a tag field so user can edit it; default to 'log'
    let tag_default = default_tag.as_deref().unwrap_or("log");
    writeln!(temp_file, "tag: {}", yaml_quote(tag_default))?;
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

    // Parse YAML frontmatter and also return date/time from frontmatter
    if let Some((loc, body, tag, title)) = parse_yaml_frontmatter(&content)? {
        // Extract frontmatter date/time if present (fallbacks to provided values)
        // For now we return the date/time strings as written in frontmatter by
        // parsing the raw content: search for `date:` and `time:` lines.
        let mut fm_date = date.to_string();
        let mut fm_time = now.time().format("%H:%M:%S").to_string();
        for line in content.lines() {
            let t = line.trim();
            if t.starts_with("date:") {
                if let Some(v) = t.splitn(2, ':').nth(1) {
                    fm_date = v.trim().trim_matches('\"').to_string();
                }
            } else if t.starts_with("time:") {
                if let Some(v) = t.splitn(2, ':').nth(1) {
                    fm_time = v.trim().trim_matches('\"').to_string();
                }
            }
        }

        return Ok(Some((fm_date, fm_time, loc, body, tag, title)));
    }
    Ok(None)
}

/// Open external editor for editing an existing entry
/// Returns (date, time, day_of_week, location, content, tag, title) after editing, or None if cancelled
pub fn edit_existing_entry(
    date_str: &str,
    time_str: &str,
    _day_of_week: &str,
    location: &str,
    content: &str,
    tag: Option<&str>,
    title: Option<&str>,
) -> Result<
    Option<(
        String,
        String,
        String,
        String,
        Option<String>,
        Option<String>,
    )>,
> {
    // Create temp file with .md extension
    let mut temp_file = NamedTempFile::with_suffix(".md").context("Failed to create temp file")?;

    // reuse same yaml_quote helper

    // Write YAML frontmatter (include existing title line when editing)
    writeln!(temp_file, "---")?;
    writeln!(temp_file, "date: {}", date_str)?;
    writeln!(temp_file, "time: {}", time_str)?;
    // Prefill the title with the provided existing title (if any)
    writeln!(temp_file, "title: {}", yaml_quote(title.unwrap_or("")))?;
    writeln!(temp_file, "location: {}", location)?;
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

    // Parse YAML and return date/time extracted from frontmatter if present
    if let Some((loc, body, tag_res, title_res)) = parse_yaml_frontmatter(&edited_content)? {
        // Extract frontmatter date/time if present
        let mut fm_date = date_str.to_string();
        let mut fm_time = time_str.to_string();
        for line in edited_content.lines() {
            let t = line.trim();
            if t.starts_with("date:") {
                if let Some(v) = t.splitn(2, ':').nth(1) {
                    fm_date = v.trim().trim_matches('\"').to_string();
                }
            } else if t.starts_with("time:") {
                if let Some(v) = t.splitn(2, ':').nth(1) {
                    fm_time = v.trim().trim_matches('\"').to_string();
                }
            }
        }

        Ok(Some((fm_date, fm_time, loc, body, tag_res, title_res)))
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
            .copied()
            .collect::<Vec<&str>>()
            .join("\n")
            .trim()
            .to_string()
    } else {
        content.trim().to_string()
    };

    // Return the body even if empty — caller decides whether empty means delete
    Ok(Some(body))
}

/// Parse the content from the editor, extracting tag from header
/// Returns (location, content, tag, title) if valid, None if cancelled
pub fn parse_yaml_frontmatter(
    content: &str,
) -> Result<Option<(String, String, Option<String>, Option<String>)>> {
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
        // No frontmatter: return location empty, content, no tag, no title
        return Ok(Some((String::new(), content_str, None, None)));
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
    let mut title: Option<String> = None;

    // Helper to remove surrounding quotes and unescape common sequences
    fn unquote_value(v: &str) -> String {
        let s = v.trim();
        if s.len() >= 2 && s.starts_with('"') && s.ends_with('"') {
            // Remove surrounding double quotes and unescape \ and \"
            let inner = &s[1..s.len() - 1];
            let unescaped = inner.replace("\\\\", "\\").replace("\\\"", "\"");
            return unescaped;
        }
        if s.len() >= 2 && s.starts_with('\'') && s.ends_with('\'') {
            // YAML single-quote style: two single-quotes represent one
            let inner = &s[1..s.len() - 1];
            let unescaped = inner.replace("''", "'");
            return unescaped;
        }
        s.to_string()
    }

    for line in &lines[start_idx + 1..end_idx] {
        if let Some(colon_pos) = line.find(':') {
            let key = line[..colon_pos].trim();
            let value = line[colon_pos + 1..].trim();
            let v = unquote_value(value);

            match key {
                // Accept location even if empty string
                "location" => {
                    location = Some(v.clone());
                }
                "tag" => {
                    if !v.is_empty() {
                        tag = Some(v.clone());
                    }
                }
                "title" => {
                    // Allow empty title -> treat as None
                    if !v.is_empty() {
                        title = Some(v.clone());
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

    // DB only stores `tag` and now `title`
    let final_tag = tag;
    let final_title = title;

    Ok(Some((final_location, content_str, final_tag, final_title)))
}
