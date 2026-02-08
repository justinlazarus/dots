package main

import (
	"time"
)

// LogEntry represents a single log entry
type LogEntry struct {
	ID       string
	Date     time.Time
	Time     time.Time
	Location string
	Tag      *string
	Title    *string
	Content  string
	Metadata map[string]string
}

// AppMode represents the current UI mode
type AppMode int

const (
	ModeDailyView AppMode = iota
	ModeEntryView
	ModeConfirmDelete
	ModeSelectEntry
	ModeDaySearchView
	ModeGlobalSearch
)

// TagFilter represents the current tag filter state
type TagFilter int

const (
	TagFilterAll TagFilter = iota
	TagFilterTag
	TagFilterUntagged
)

// MonthlySummaries stores summaries for each day
type MonthlySummaries struct {
	Summaries map[string]string // key is date string YYYY-MM-DD
}

func NewMonthlySummaries() *MonthlySummaries {
	return &MonthlySummaries{
		Summaries: make(map[string]string),
	}
}

func (m *MonthlySummaries) GetSummary(date time.Time) string {
	key := date.Format("2006-01-02")
	if s, ok := m.Summaries[key]; ok {
		return s
	}
	return ""
}

func (m *MonthlySummaries) SetSummary(date time.Time, text string) {
	key := date.Format("2006-01-02")
	if text == "" {
		delete(m.Summaries, key)
	} else {
		m.Summaries[key] = text
	}
}
