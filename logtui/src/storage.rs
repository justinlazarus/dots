use anyhow::{anyhow, Context, Result};
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
    let pwd = env::current_dir().context("Failed to get current directory")?;
    let pattern = Regex::new(r"^\d{4}\.md$").unwrap();

    for entry in fs::read_dir(&pwd).context("Failed to read current directory")? {
        let entry = entry.context("Failed to read directory entry")?;
        let filename = entry.file_name();
        let filename_str = filename.to_string_lossy();

        if pattern.is_match(&filename_str) {
            return Ok(entry.path());
        }
    }

    Err(anyhow!(
        "No log file found in current directory. Expected format: YYYY.md (e.g., 2026.md)"
    ))
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
    fs::read_to_string(path)
        .with_context(|| format!("Failed to read log file: {}", path.display()))
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
