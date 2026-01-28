use crate::models::LogEntry;
use anyhow::Result;
use chrono::NaiveDate;
use rusqlite::{params, Connection};
use std::path::Path;

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn open(path: &Path) -> Result<Self> {
        let mut conn = Connection::open(path)?;
        // Ensure table exists with nullable location. If an older table exists with
        // NOT NULL location we perform a migration to a new table with location NULLABLE.
        conn.execute(
            "CREATE TABLE IF NOT EXISTS logs (
                id TEXT PRIMARY KEY,
                date TEXT NOT NULL,
                time TEXT NOT NULL,
                location TEXT,
                tag TEXT,
                content TEXT NOT NULL
            )",
            [],
        )?;

        // Detect if existing table has a NOT NULL constraint on location and migrate if needed
        let mut has_notnull_location = false;
        // Run PRAGMA in its own scope so Statement is dropped before we start a transaction
        {
            let mut stmt = conn.prepare("PRAGMA table_info(logs)")?;
            let mut rows = stmt.query([])?;
            while let Some(row) = rows.next()? {
                let col_name: String = row.get(1)?; // name
                let notnull: i64 = row.get(3)?; // notnull flag
                if col_name == "location" && notnull == 1 {
                    has_notnull_location = true;
                    break;
                }
            }
        }

        if has_notnull_location {
            // Perform safe migration within transaction
            let tx = conn.transaction()?;
            tx.execute(
                "CREATE TABLE IF NOT EXISTS logs_new (
                    id TEXT PRIMARY KEY,
                    date TEXT NOT NULL,
                    time TEXT NOT NULL,
                    location TEXT,
                    tag TEXT,
                    content TEXT NOT NULL
                )",
                [],
            )?;

            // Copy data over; allow NULL when location is empty string
            tx.execute(
                "INSERT INTO logs_new (id,date,time,location,tag,content)
                 SELECT id,date,time,
                        CASE WHEN trim(location) = '' THEN NULL ELSE location END,
                        tag,content FROM logs",
                [],
            )?;

            tx.execute("DROP TABLE logs", [])?;
            tx.execute("ALTER TABLE logs_new RENAME TO logs", [])?;
            tx.execute("CREATE INDEX IF NOT EXISTS idx_logs_date ON logs(date)", [])?;
            tx.commit()?;
        }
        // Index for fast chronological sorting in the TUI
        conn.execute("CREATE INDEX IF NOT EXISTS idx_logs_date ON logs(date)", [])?;
        Ok(Self { conn })
    }

    pub fn save_entry(&self, entry: &LogEntry) -> Result<()> {
        // Store NULL for location when empty string
        let loc_param: Option<&str> = if entry.location.is_empty() {
            None
        } else {
            Some(entry.location.as_str())
        };

        self.conn.execute(
            "INSERT INTO logs (id, date, time, location, tag, content) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                entry.id,
                entry.date.to_string(),
                entry.time.to_string(),
                loc_param,
                entry.tag.as_deref(),
                entry.content
            ],
        )?;
        Ok(())
    }

    pub fn update_entry(&self, entry: &LogEntry) -> Result<()> {
        let loc_param: Option<&str> = if entry.location.is_empty() {
            None
        } else {
            Some(entry.location.as_str())
        };

        self.conn.execute(
            "UPDATE logs SET date = ?2, time = ?3, location = ?4, tag = ?5, content = ?6 WHERE id = ?1",
            params![
                entry.id,
                entry.date.to_string(),
                entry.time.to_string(),
                loc_param,
                entry.tag.as_deref(),
                entry.content
            ],
        )?;
        Ok(())
    }

    pub fn delete_entry(&self, id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM logs WHERE id = ?1", params![id])?;
        Ok(())
    }

    /// Return the most recent entry's location, if any
    // previously had get_last_location helper; removed since app no longer tracks last_location

    pub fn get_entries_for_date(&self, date: NaiveDate) -> Result<Vec<LogEntry>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, date, time, location, tag, content FROM logs WHERE date = ? ORDER BY time ASC",
        )?;
        let rows = stmt.query_map([date.to_string()], |row| {
            Ok(LogEntry {
                id: row.get(0)?,
                date: row.get::<_, String>(1)?.parse().unwrap(),
                time: row.get::<_, String>(2)?.parse().unwrap(),
                location: row.get::<_, Option<String>>(3)?.unwrap_or_default(),
                tag: row.get(4)?,
                content: row.get(5)?,
            })
        })?;

        let mut entries = Vec::new();
        for row in rows {
            entries.push(row?);
        }
        Ok(entries)
    }

    /// Search across all entries for matching content or location
    pub fn search_entries(&self, query: &str) -> Result<Vec<(NaiveDate, usize)>> {
        if query.is_empty() {
            return Ok(Vec::new());
        }

        let query_lower = format!("%{}%", query.to_lowercase());
        let mut stmt = self.conn.prepare(
            "SELECT date, time FROM logs 
             WHERE LOWER(content) LIKE ?1 OR (location IS NOT NULL AND LOWER(location) LIKE ?1) 
             ORDER BY date DESC, time DESC",
        )?;

        let rows = stmt.query_map([&query_lower], |row| {
            let date_str: String = row.get(0)?;
            let date: NaiveDate = date_str.parse().unwrap();
            Ok(date)
        })?;

        let mut results = Vec::new();
        let mut current_date: Option<NaiveDate> = None;
        let mut entry_index = 0;

        for row in rows {
            let date = row?;

            // Reset index when we move to a different date
            if current_date != Some(date) {
                current_date = Some(date);
                entry_index = 0;
            } else {
                entry_index += 1;
            }

            results.push((date, entry_index));
        }

        Ok(results)
    }

    /// The "Git-Saver": Dumps the DB to your favorite Markdown format
    pub fn export_to_markdown(&self, path: &Path) -> Result<()> {
        let mut stmt = self.conn.prepare(
            "SELECT date, time, location, tag, content FROM logs ORDER BY date DESC, time DESC",
        )?;

        let mut rows = stmt.query([])?;
        let mut content = String::new();

        while let Some(row) = rows.next()? {
            let date: String = row.get(0)?;
            let time: String = row.get(1)?;
            let location: Option<String> = row.get(2)?;
            let tag: Option<String> = row.get(3)?;
            let body: String = row.get(4)?;

            let loc_display = location.unwrap_or_default();

            content.push_str(&format!(
                "## {} {} - {}{}\n\n",
                date,
                time,
                loc_display,
                match tag {
                    Some(t) => format!(" #{}", t),
                    None => "".to_string(),
                }
            ));
            content.push_str(&body);
            content.push_str("\n\n");
        }

        std::fs::write(path, content)?;
        Ok(())
    }
}
