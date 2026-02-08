package db

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"tlog/internal/model"

	_ "modernc.org/sqlite"
)

type Database struct {
	conn *sql.DB
}

func OpenDatabase(path string) (*Database, error) {
	conn, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Create tables
	_, err = conn.Exec(`
		CREATE TABLE IF NOT EXISTS logs (
			id TEXT PRIMARY KEY,
			date TEXT NOT NULL,
			time TEXT NOT NULL,
			location TEXT,
			tag TEXT,
			title TEXT,
			content TEXT NOT NULL,
			metadata TEXT
		)
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to create logs table: %w", err)
	}

	// Migrate: add metadata column if it doesn't exist (for existing DBs)
	conn.Exec(`ALTER TABLE logs ADD COLUMN metadata TEXT`)

	// Create index
	_, err = conn.Exec(`CREATE INDEX IF NOT EXISTS idx_logs_date ON logs(date)`)
	if err != nil {
		return nil, fmt.Errorf("failed to create index: %w", err)
	}

	// Create summaries table
	_, err = conn.Exec(`
		CREATE TABLE IF NOT EXISTS summaries (
			date TEXT PRIMARY KEY,
			text TEXT NOT NULL
		)
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to create summaries table: %w", err)
	}

	return &Database{conn: conn}, nil
}

func (db *Database) Close() error {
	return db.conn.Close()
}

func (db *Database) SaveEntry(entry *model.LogEntry) error {
	var loc *string
	if entry.Location != "" {
		loc = &entry.Location
	}

	var metadataJSON *string
	if len(entry.Metadata) > 0 {
		b, _ := json.Marshal(entry.Metadata)
		s := string(b)
		metadataJSON = &s
	}

	_, err := db.conn.Exec(`
		INSERT INTO logs (id, date, time, location, tag, title, content, metadata)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`,
		entry.ID,
		entry.Date.Format("2006-01-02"),
		entry.Time.Format("15:04:05"),
		loc,
		entry.Tag,
		entry.Title,
		entry.Content,
		metadataJSON,
	)
	return err
}

func (db *Database) UpdateEntry(entry *model.LogEntry) error {
	var loc *string
	if entry.Location != "" {
		loc = &entry.Location
	}

	var metadataJSON *string
	if len(entry.Metadata) > 0 {
		b, _ := json.Marshal(entry.Metadata)
		s := string(b)
		metadataJSON = &s
	}

	_, err := db.conn.Exec(`
		UPDATE logs SET date = ?, time = ?, location = ?, tag = ?, title = ?, content = ?, metadata = ?
		WHERE id = ?
	`,
		entry.Date.Format("2006-01-02"),
		entry.Time.Format("15:04:05"),
		loc,
		entry.Tag,
		entry.Title,
		entry.Content,
		metadataJSON,
		entry.ID,
	)
	return err
}

func (db *Database) DeleteEntry(id string) error {
	_, err := db.conn.Exec(`DELETE FROM logs WHERE id = ?`, id)
	return err
}

func (db *Database) GetEntriesForDate(date time.Time) ([]model.LogEntry, error) {
	dateStr := date.Format("2006-01-02")
	rows, err := db.conn.Query(`
		SELECT id, date, time, location, tag, title, content, metadata
		FROM logs
		WHERE date = ?
		ORDER BY time ASC
	`, dateStr)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []model.LogEntry
	for rows.Next() {
		var e model.LogEntry
		var dateStr, timeStr string
		var loc, tag, title, metadata sql.NullString

		err := rows.Scan(&e.ID, &dateStr, &timeStr, &loc, &tag, &title, &e.Content, &metadata)
		if err != nil {
			return nil, err
		}

		e.Date, _ = time.Parse("2006-01-02", dateStr)
		e.Time, _ = time.Parse("15:04:05", timeStr)
		if loc.Valid {
			e.Location = loc.String
		}
		if tag.Valid {
			e.Tag = &tag.String
		}
		if title.Valid {
			e.Title = &title.String
		}
		if metadata.Valid {
			json.Unmarshal([]byte(metadata.String), &e.Metadata)
		}

		entries = append(entries, e)
	}

	return entries, nil
}

func (db *Database) SearchEntries(query string) ([]model.SearchResult, error) {
	if query == "" {
		return nil, nil
	}

	queryLower := "%" + strings.ToLower(query) + "%"
	rows, err := db.conn.Query(`
		SELECT date, time FROM logs
		WHERE LOWER(content) LIKE ?
			OR (location IS NOT NULL AND LOWER(location) LIKE ?)
			OR (metadata IS NOT NULL AND LOWER(metadata) LIKE ?)
		ORDER BY date DESC, time DESC
	`, queryLower, queryLower, queryLower)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.SearchResult
	var currentDate string
	entryIndex := 0

	for rows.Next() {
		var dateStr, timeStr string
		if err := rows.Scan(&dateStr, &timeStr); err != nil {
			return nil, err
		}

		if dateStr != currentDate {
			currentDate = dateStr
			entryIndex = 0
		} else {
			entryIndex++
		}

		date, _ := time.Parse("2006-01-02", dateStr)
		results = append(results, model.SearchResult{Date: date, EntryIndex: entryIndex})
	}

	return results, nil
}

func (db *Database) SetSummary(date time.Time, text string) error {
	dateStr := date.Format("2006-01-02")
	if strings.TrimSpace(text) == "" {
		_, err := db.conn.Exec(`DELETE FROM summaries WHERE date = ?`, dateStr)
		return err
	}

	_, err := db.conn.Exec(`
		INSERT INTO summaries (date, text) VALUES (?, ?)
		ON CONFLICT(date) DO UPDATE SET text = excluded.text
	`, dateStr, text)
	return err
}

func (db *Database) GetAllSummaries() (map[string]string, error) {
	rows, err := db.conn.Query(`SELECT date, text FROM summaries`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	summaries := make(map[string]string)
	for rows.Next() {
		var dateStr, text string
		if err := rows.Scan(&dateStr, &text); err != nil {
			return nil, err
		}
		summaries[dateStr] = text
	}

	return summaries, nil
}

func (db *Database) ExportToMarkdown(path string) error {
	rows, err := db.conn.Query(`
		SELECT date, time, location, tag, title, content, metadata
		FROM logs
		ORDER BY date DESC, time DESC
	`)
	if err != nil {
		return err
	}
	defer rows.Close()

	var content strings.Builder
	for rows.Next() {
		var dateStr, timeStr, body string
		var loc, tag, title, metadata sql.NullString

		if err := rows.Scan(&dateStr, &timeStr, &loc, &tag, &title, &body, &metadata); err != nil {
			return err
		}

		locDisplay := ""
		if loc.Valid {
			locDisplay = loc.String
		}

		tagSuffix := ""
		if tag.Valid {
			tagSuffix = fmt.Sprintf(" #%s", tag.String)
		}

		titleSuffix := ""
		if title.Valid {
			titleSuffix = fmt.Sprintf(" - %s", title.String)
		}

		fmt.Fprintf(&content, "## %s %s - %s%s%s\n\n", dateStr, timeStr, locDisplay, tagSuffix, titleSuffix)

		if metadata.Valid {
			var meta map[string]string
			if json.Unmarshal([]byte(metadata.String), &meta) == nil && len(meta) > 0 {
				for k, v := range meta {
					fmt.Fprintf(&content, "- **%s**: %s\n", k, v)
				}
				content.WriteString("\n")
			}
		}

		content.WriteString(body)
		content.WriteString("\n\n")
	}

	return os.WriteFile(path, []byte(content.String()), 0644)
}
