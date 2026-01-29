use anyhow::{Context, Result};
use chrono::Datelike;
use std::fs;
use std::io::{self, Read, Write};
use std::path::PathBuf;
use std::process::exit;

use tempfile::NamedTempFile;

use logtui::parser;
use logtui::{db::Database, editor, models::LogEntry};

fn usage() {
    eprintln!("Usage: migrate --file <YEAR.md> [--db <path>] [--dry-run]");
}

fn prompt_choice() -> io::Result<char> {
    // Read a single byte from stdin (user should press key + Enter)
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    Ok(input.trim().chars().next().unwrap_or('\n'))
}

fn backup_db(db_path: &PathBuf) -> Result<Option<PathBuf>> {
    if !db_path.exists() {
        return Ok(None);
    }
    let ts = chrono::Local::now().format("%Y%m%d%H%M%S").to_string();
    let mut backup = db_path.clone();
    backup.set_extension(format!("db.bak.{}", ts));
    fs::copy(db_path, &backup).context("Failed to backup database")?;
    Ok(Some(backup))
}

fn main() -> Result<()> {
    // Basic arg parsing
    let mut args = std::env::args().skip(1);
    let mut file: Option<PathBuf> = None;
    let mut db_path = PathBuf::from("logs.db");
    let mut dry_run = false;

    while let Some(a) = args.next() {
        match a.as_str() {
            "--file" => file = args.next().map(PathBuf::from),
            "--db" => db_path = args.next().map(PathBuf::from).unwrap_or(db_path),
            "--dry-run" => dry_run = true,
            _ => {
                eprintln!("Unknown arg: {}", a);
                usage();
                exit(2);
            }
        }
    }

    let file = match file {
        Some(p) => p,
        None => {
            usage();
            exit(2);
        }
    };

    let content = fs::read_to_string(&file).context("Failed to read source file")?;

    // Infer year from filename or fallback to current year
    let year = if let Some(stem) = file.file_stem().and_then(|s| s.to_str()) {
        stem.parse::<i32>()
            .unwrap_or_else(|_| chrono::Local::now().year())
    } else {
        chrono::Local::now().year()
    };

    let parsed = parser::parse_log_file(&content, year).context("Failed to parse log file")?;

    // Flatten entries into chronological order
    let mut all: Vec<LogEntry> = Vec::new();
    let mut dates: Vec<_> = parsed.keys().cloned().collect();
    dates.sort();
    for d in dates {
        if let Some(mut v) = parsed.get(&d).cloned() {
            // Already sorted by parser
            all.append(&mut v);
        }
    }

    println!("Parsed {} entries from {}", all.len(), file.display());
    if all.is_empty() {
        return Ok(());
    }

    if dry_run {
        for (i, e) in all.iter().enumerate() {
            println!(
                "[{}] {} {} - {} ({} bytes)",
                i + 1,
                e.date,
                e.time,
                e.location,
                e.content.len()
            );
        }
        return Ok(());
    }

    // Backup DB
    let _bak = backup_db(&db_path).ok();

    // Open DB
    let database = Database::open(&db_path).context("Failed to open database")?;

    let mut inserted = 0usize;
    let mut skipped = 0usize;

    'outer: for (idx, entry) in all.into_iter().enumerate() {
        println!(
            "\nEntry {}/{}: {} {} - {}",
            idx + 1,
            /*total*/ "?",
            entry.date,
            entry.time,
            entry.location
        );

        // Create temp file prefilled using editor::edit_existing_entry's format
        let mut tmp = NamedTempFile::new().context("Failed to create temp file")?;
        writeln!(tmp, "---")?;
        writeln!(tmp, "date: {}", entry.date)?;
        writeln!(tmp, "time: {}", entry.time)?;
        writeln!(tmp, "title: {}", "")?;
        writeln!(tmp, "location: {}", entry.location)?;
        if let Some(tag) = &entry.tag {
            writeln!(tmp, "tag: {}", tag)?;
        }
        writeln!(tmp, "---")?;
        writeln!(tmp)?;
        writeln!(tmp, "{}", entry.content)?;
        tmp.flush()?;

        loop {
            // Launch editor
            let editor = editor::get_editor();
            let status = std::process::Command::new(&editor)
                .arg(tmp.path())
                .status()
                .with_context(|| format!("Failed to launch editor: {}", editor))?;

            if !status.success() {
                eprintln!("Editor exited with non-zero status; skipping this entry");
                skipped += 1;
                break;
            }

            let buf = fs::read_to_string(tmp.path()).context("Failed to read temp file")?;
            if let Some((loc, body, tag, title)) = editor::parse_yaml_frontmatter(&buf)? {
                if body.trim().is_empty() {
                    println!("Content empty — skipping entry");
                    skipped += 1;
                    break;
                }

                println!(
                    "Preview: {} {} - {}\n{}\n",
                    entry.date,
                    entry.time,
                    loc,
                    &body.lines().take(3).collect::<Vec<_>>().join("\n")
                );
                println!("[Enter]=Insert  s=Skip  e=Edit again  q=Quit");
                print!("> ");
                io::stdout().flush()?;
                let choice = prompt_choice()?;
                match choice {
                    '\n' | '\r' => {
                        // Insert
                        let new_entry = LogEntry {
                            id: ulid::Ulid::new().to_string(),
                            date: entry.date,
                            time: entry.time,
                            location: loc,
                            tag,
                            title,
                            content: body,
                        };
                        database.save_entry(&new_entry)?;
                        inserted += 1;
                        break;
                    }
                    's' | 'S' => {
                        skipped += 1;
                        break;
                    }
                    'e' | 'E' => {
                        // loop and re-edit same tmp file
                        continue;
                    }
                    'q' | 'Q' => {
                        println!("Aborting migration");
                        break 'outer;
                    }
                    _ => {
                        // default to insert
                        let new_entry = LogEntry {
                            id: ulid::Ulid::new().to_string(),
                            date: entry.date,
                            time: entry.time,
                            location: loc,
                            tag,
                            title,
                            content: body,
                        };
                        database.save_entry(&new_entry)?;
                        inserted += 1;
                        break;
                    }
                }
            } else {
                println!("No frontmatter parsed — skipping");
                skipped += 1;
                break;
            }
        }
    }

    println!("\nDone. Inserted: {}, Skipped: {}", inserted, skipped);

    // Export to archive.md similar to app exit
    database.export_to_markdown(std::path::Path::new("archive.md"))?;

    Ok(())
}
