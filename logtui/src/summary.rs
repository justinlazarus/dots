use anyhow::{Context, Result};
use chrono::{Datelike, NaiveDate};
use regex::Regex;
use std::collections::HashMap;

/// Stores summaries for each day
#[derive(Debug, Clone)]
pub struct MonthlySummaries {
    pub summaries: HashMap<NaiveDate, String>,
}

impl MonthlySummaries {
    pub fn new() -> Self {
        Self {
            summaries: HashMap::new(),
        }
    }

    /// Get summary for a given date, returns empty string if no summary
    pub fn get_summary(&self, date: &NaiveDate) -> String {
        self.summaries.get(date).cloned().unwrap_or_default()
    }

    pub fn set_summary(&mut self, date: NaiveDate, text: &str) {
        if text.trim().is_empty() {
            self.summaries.remove(&date);
        } else {
            self.summaries.insert(date, text.to_string());
        }
    }
}

/// Parse the summary markdown file
/// Format: "- MM/DD summary text here"
pub fn parse_summary_file(content: &str, year: i32) -> Result<MonthlySummaries> {
    let mut summaries = MonthlySummaries::new();

    // Regex to match: "- 01/15 lily school performance"
    // Also matches: "- 01/15 - lily school performance" (with dash after date)
    let entry_re = Regex::new(r"^-\s*(\d{2})/(\d{2})\s*-?\s*(.*)$").unwrap();

    for line in content.lines() {
        if let Some(caps) = entry_re.captures(line) {
            let month: u32 = caps
                .get(1)
                .unwrap()
                .as_str()
                .parse()
                .context("Invalid month in summary")?;
            let day: u32 = caps
                .get(2)
                .unwrap()
                .as_str()
                .parse()
                .context("Invalid day in summary")?;
            let text = caps.get(3).unwrap().as_str().trim().to_string();

            // Create date and store summary
            if let Some(date) = NaiveDate::from_ymd_opt(year, month, day) {
                summaries.summaries.insert(date, text);
            }
        }
    }

    Ok(summaries)
}

/// Write summaries back out to a markdown file in a simple structure
pub fn write_summary_file(
    path: &std::path::Path,
    year: i32,
    summaries: &MonthlySummaries,
) -> Result<()> {
    use std::fs::File;
    use std::io::Write;

    let mut file = File::create(path).context("Failed to open summary file for writing")?;
    writeln!(file, "# {} Daily Summaries", year)?;
    writeln!(file)?;

    // Group by month
    let mut by_month: std::collections::BTreeMap<u32, Vec<(u32, String)>> =
        std::collections::BTreeMap::new();
    for (date, text) in &summaries.summaries {
        by_month
            .entry(date.month())
            .or_default()
            .push((date.day(), text.clone()));
    }

    for (month, entries) in by_month {
        let month_name = chrono::NaiveDate::from_ymd_opt(year, month, 1)
            .map(|d| d.format("%B").to_string())
            .unwrap_or_else(|| format!("Month {}", month));
        writeln!(file, "## {}", month_name)?;
        writeln!(file)?;
        for (day, text) in entries {
            writeln!(file, "- {:02}/{:02} {}", month, day, text)?;
        }
        writeln!(file)?;
    }

    // UI hint: We don't write summaries.md anymore but keep writer for compatibility

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_summary_file() {
        let content = r#"
# 2026 Daily Summaries

## January

- 01/01 nikki back to atl, crochet
- 01/02 cathy to kim's house, packing
- 01/04 - little shopping, loafing about
"#;

        let summaries = parse_summary_file(content, 2026).unwrap();

        let jan1 = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
        assert_eq!(summaries.get_summary(&jan1), "nikki back to atl, crochet");

        let jan2 = NaiveDate::from_ymd_opt(2026, 1, 2).unwrap();
        assert_eq!(
            summaries.get_summary(&jan2),
            "cathy to kim's house, packing"
        );

        let jan3 = NaiveDate::from_ymd_opt(2026, 1, 3).unwrap();
        assert_eq!(summaries.get_summary(&jan3), ""); // No entry

        let jan4 = NaiveDate::from_ymd_opt(2026, 1, 4).unwrap();
        assert_eq!(
            summaries.get_summary(&jan4),
            "little shopping, loafing about"
        );
    }

    #[test]
    fn test_empty_summary() {
        let summaries = parse_summary_file("", 2026).unwrap();
        let jan1 = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
        assert_eq!(summaries.get_summary(&jan1), "");
    }

    #[test]
    fn test_long_summary_text() {
        let content =
            "- 01/22 cold af hands on the run, angel helped me pick lily cuz i had meeting";
        let summaries = parse_summary_file(content, 2026).unwrap();
        let jan22 = NaiveDate::from_ymd_opt(2026, 1, 22).unwrap();
        assert_eq!(
            summaries.get_summary(&jan22),
            "cold af hands on the run, angel helped me pick lily cuz i had meeting"
        );
    }
}
