package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"time"
)

func getEditor() string {
	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = "nvim"
	}
	switch editor {
	case "neovim":
		return "nvim"
	default:
		return editor
	}
}

func yamlQuote(s string) string {
	if s == "" {
		return ""
	}
	if strings.HasPrefix(s, " ") || strings.HasSuffix(s, " ") || strings.Contains(s, ":") || strings.Contains(s, "\"") {
		escaped := strings.ReplaceAll(s, "\\", "\\\\")
		escaped = strings.ReplaceAll(escaped, "\"", "\\\"")
		return fmt.Sprintf("\"%s\"", escaped)
	}
	return s
}

// CreateNewEntryTempFile creates a temp file for a new entry and returns its path
func CreateNewEntryTempFile(location *string, defaultTag *string, date time.Time) (string, error) {
	tmpFile, err := os.CreateTemp("", "tlog-*.md")
	if err != nil {
		return "", fmt.Errorf("failed to create temp file: %w", err)
	}

	now := time.Now()
	loc := ""
	if location != nil {
		loc = *location
	}
	tag := "log"
	if defaultTag != nil {
		tag = *defaultTag
	}

	// Write YAML frontmatter
	fmt.Fprintln(tmpFile, "---")
	fmt.Fprintf(tmpFile, "date: %s\n", date.Format("2006-01-02"))
	fmt.Fprintf(tmpFile, "time: %s\n", now.Format("15:04:05"))
	fmt.Fprintf(tmpFile, "title: %s\n", yamlQuote(""))
	fmt.Fprintf(tmpFile, "location: %s\n", yamlQuote(loc))
	fmt.Fprintf(tmpFile, "tag: %s\n", yamlQuote(tag))
	fmt.Fprintln(tmpFile, "---")
	fmt.Fprintln(tmpFile)
	tmpFile.Close()

	return tmpFile.Name(), nil
}

// CreateEditEntryTempFile creates a temp file for editing an existing entry
func CreateEditEntryTempFile(dateStr, timeStr, location, content string, tag, title *string) (string, error) {
	tmpFile, err := os.CreateTemp("", "tlog-*.md")
	if err != nil {
		return "", fmt.Errorf("failed to create temp file: %w", err)
	}

	titleStr := ""
	if title != nil {
		titleStr = *title
	}

	// Write YAML frontmatter
	fmt.Fprintln(tmpFile, "---")
	fmt.Fprintf(tmpFile, "date: %s\n", dateStr)
	fmt.Fprintf(tmpFile, "time: %s\n", timeStr)
	fmt.Fprintf(tmpFile, "title: %s\n", yamlQuote(titleStr))
	fmt.Fprintf(tmpFile, "location: %s\n", location)
	if tag != nil {
		fmt.Fprintf(tmpFile, "tag: %s\n", *tag)
	}
	fmt.Fprintln(tmpFile, "---")
	fmt.Fprintln(tmpFile)
	fmt.Fprintln(tmpFile, content)
	tmpFile.Close()

	return tmpFile.Name(), nil
}

// CreateSummaryTempFile creates a temp file for editing a day's summary
func CreateSummaryTempFile(date time.Time, current string) (string, error) {
	tmpFile, err := os.CreateTemp("", "tlog-summary-*.md")
	if err != nil {
		return "", fmt.Errorf("failed to create temp file: %w", err)
	}

	fmt.Fprintf(tmpFile, "# Summary for %s\n\n", date.Format("2006-01-02"))
	fmt.Fprintln(tmpFile, current)
	tmpFile.Close()

	return tmpFile.Name(), nil
}

// EntryResult holds the parsed result from the editor
type EntryResult struct {
	Date     string
	Time     string
	Location string
	Content  string
	Tag      *string
	Title    *string
}

func parseYAMLFrontmatter(content, defaultDate, defaultTime string) (*EntryResult, error) {
	lines := strings.Split(content, "\n")
	if len(lines) == 0 {
		return nil, nil
	}

	// Find frontmatter delimiters
	startIdx := -1
	endIdx := -1
	for i, line := range lines {
		if strings.TrimSpace(line) == "---" {
			if startIdx == -1 {
				startIdx = i
			} else {
				endIdx = i
				break
			}
		}
	}

	if startIdx == -1 {
		// No frontmatter
		contentStr := strings.TrimSpace(content)
		if contentStr == "" {
			return nil, nil
		}
		return &EntryResult{
			Date:    defaultDate,
			Time:    defaultTime,
			Content: contentStr,
		}, nil
	}

	if endIdx == -1 {
		return nil, nil
	}

	result := &EntryResult{
		Date: defaultDate,
		Time: defaultTime,
	}

	// Parse frontmatter
	for _, line := range lines[startIdx+1 : endIdx] {
		colonIdx := strings.Index(line, ":")
		if colonIdx == -1 {
			continue
		}
		key := strings.TrimSpace(line[:colonIdx])
		value := unquoteValue(strings.TrimSpace(line[colonIdx+1:]))

		switch key {
		case "date":
			result.Date = value
		case "time":
			result.Time = value
		case "location":
			result.Location = value
		case "tag":
			if value != "" {
				result.Tag = &value
			}
		case "title":
			if value != "" {
				result.Title = &value
			}
		}
	}

	// Get content after frontmatter
	if endIdx+1 < len(lines) {
		result.Content = strings.TrimSpace(strings.Join(lines[endIdx+1:], "\n"))
	}

	return result, nil
}

func unquoteValue(v string) string {
	s := strings.TrimSpace(v)
	if len(s) >= 2 && strings.HasPrefix(s, "\"") && strings.HasSuffix(s, "\"") {
		inner := s[1 : len(s)-1]
		inner = strings.ReplaceAll(inner, "\\\\", "\\")
		inner = strings.ReplaceAll(inner, "\\\"", "\"")
		return inner
	}
	if len(s) >= 2 && strings.HasPrefix(s, "'") && strings.HasSuffix(s, "'") {
		inner := s[1 : len(s)-1]
		inner = strings.ReplaceAll(inner, "''", "'")
		return inner
	}
	return s
}

// Helper for reading user input
func promptChoice() (rune, error) {
	reader := bufio.NewReader(os.Stdin)
	line, err := reader.ReadString('\n')
	if err != nil {
		return 0, err
	}
	line = strings.TrimSpace(line)
	if len(line) == 0 {
		return '\n', nil
	}
	return rune(line[0]), nil
}
