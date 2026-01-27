use anyhow::{anyhow, Context, Result};
use chrono::Datelike;
use regex::Regex;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

/// Find a log file following the YYYY.md pattern
/// Priority 1: CLI override path
/// Priority 2: YYYY.md file in current working directory
pub fn find_log_file(cli_override: Option<PathBuf>) -> Result<PathBuf> {
    // Priority 1: CLI override
    if let Some(path) = cli_override {
        if !path.exists() {
            return Err(anyhow!("File not found: {}", path.display()));
        }
        return Ok(path);
    }

    // Priority 2: Find YYYY.md in current working directory
    // Prefer current year, then most recent year
    let pwd = env::current_dir().context("Failed to get current directory")?;
    let pattern = Regex::new(r"^\d{4}\.md$").unwrap();
    let current_year = chrono::Local::now().year();

    let mut found_files: Vec<(i32, PathBuf)> = Vec::new();

    for entry in fs::read_dir(&pwd).context("Failed to read current directory")? {
        let entry = entry.context("Failed to read directory entry")?;
        let filename = entry.file_name();
        let filename_str = filename.to_string_lossy();

        if pattern.is_match(&filename_str) {
            // Extract year from filename
            if let Ok(year) = filename_str.trim_end_matches(".md").parse::<i32>() {
                found_files.push((year, entry.path()));
            }
        }
    }

    if found_files.is_empty() {
        return Err(anyhow!(
            "No log file found in current directory. Expected format: YYYY.md (e.g., 2026.md)"
        ));
    }

    // Sort by year descending and prefer current year
    found_files.sort_by(|a, b| {
        if a.0 == current_year {
            std::cmp::Ordering::Less
        } else if b.0 == current_year {
            std::cmp::Ordering::Greater
        } else {
            b.0.cmp(&a.0) // Most recent year first
        }
    });

    Ok(found_files[0].1.clone())
}

/// Extract year from filename (e.g., "2026.md" -> 2026)
pub fn extract_year_from_filename(path: &Path) -> Result<i32> {
    path.file_stem()
        .and_then(|s| s.to_str())
        .and_then(|s| s.parse::<i32>().ok())
        .ok_or_else(|| anyhow!("Invalid log filename format. Expected YYYY.md (e.g., 2026.md)"))
}

/// Read the entire log file as a string
pub fn read_log_file(path: &Path) -> Result<String> {
    fs::read_to_string(path).with_context(|| format!("Failed to read log file: {}", path.display()))
}

/// Write content to the log file
pub fn write_log_file(path: &Path, content: &str) -> Result<()> {
    fs::write(path, content)
        .with_context(|| format!("Failed to write log file: {}", path.display()))
}

/// Create a new log file with header if it doesn't exist
pub fn create_log_file_if_missing(path: &Path, year: i32) -> Result<()> {
    if !path.exists() {
        let header = format!("# {} Log\n\n", year);
        write_log_file(path, &header)?;
    }
    Ok(())
}

/// Get the path to the summary file for a given log file
pub fn get_summary_path(log_path: &PathBuf) -> Result<PathBuf> {
    let parent = log_path
        .parent()
        .context("Log file has no parent directory")?;

    let summary_filename = log_path
        .file_stem()
        .context("Log file has no filename")?
        .to_str()
        .context("Invalid filename")?;

    Ok(parent.join(format!("{}-summaries.md", summary_filename)))
}

/// Read the summary file for the current year
/// Returns empty string if file doesn't exist
pub fn read_summary_file(log_path: &PathBuf) -> Result<String> {
    // Given: /Users/djpoo/log/2026/2026.md
    // Find:  /Users/djpoo/log/2026/2026-summaries.md

    let summary_path = get_summary_path(log_path)?;

    if !summary_path.exists() {
        return Ok(String::new());
    }

    fs::read_to_string(summary_path).context("Failed to read summary file")
}

/// Write the summary file
pub fn write_summary_file(log_path: &PathBuf, content: &str) -> Result<()> {
    let summary_path = get_summary_path(log_path)?;
    fs::write(&summary_path, content)
        .with_context(|| format!("Failed to write summary file: {}", summary_path.display()))
}

/// Find a log file for a specific year in the same directory as the current log file
/// Creates the file if it doesn't exist
pub fn find_log_file_for_year(current_log_path: &PathBuf, year: i32) -> Result<PathBuf> {
    let parent = current_log_path
        .parent()
        .context("Log file has no parent directory")?;

    let target_filename = format!("{}.md", year);
    let target_path = parent.join(&target_filename);

    // Create the file if it doesn't exist
    if !target_path.exists() {
        let header = format!("# {} Log\n\n", year);
        fs::write(&target_path, header)
            .with_context(|| format!("Failed to create log file: {}", target_path.display()))?;
    }

    Ok(target_path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_year_from_filename() {
        let path = PathBuf::from("/some/path/2026.md");
        assert_eq!(extract_year_from_filename(&path).unwrap(), 2026);

        let path = PathBuf::from("2025.md");
        assert_eq!(extract_year_from_filename(&path).unwrap(), 2025);

        let path = PathBuf::from("invalid.md");
        assert!(extract_year_from_filename(&path).is_err());
    }
}
