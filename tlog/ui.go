package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Styles
var (
	headerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("15"))

	selectedStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("11")) // Yellow

	tagStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("14")) // Cyan

	dimStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("8")) // Gray

	borderStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("8"))

	modeStyle = lipgloss.NewStyle().
			Bold(true).
			Background(lipgloss.Color("2")).
			Foreground(lipgloss.Color("0")).
			Padding(0, 1)
)

// Model is the main application state
type Model struct {
	db               *Database
	currentDate      time.Time
	entries          []LogEntry
	monthlySummaries *MonthlySummaries
	mode             AppMode
	scrollOffset     int
	selectedIndex    int
	currentTagFilter TagFilter
	filterTag        string
	searchQuery      string
	daySearchQuery   string

	// Global search state
	searchResults       []SearchResult
	selectedSearchIndex int

	returnToSelection    bool
	confirmFromSelection bool
	prevSelectedIndex    *int

	viewportHeight int
	viewportWidth  int
	shouldQuit     bool

	// Links from rendered content
	lastRenderedLinks []string
}

func NewModel(db *Database) Model {
	today := time.Now()
	entries, _ := db.GetEntriesForDate(today)

	summaries, _ := db.GetAllSummaries()
	ms := NewMonthlySummaries()
	ms.Summaries = summaries

	return Model{
		db:               db,
		currentDate:      today,
		entries:          entries,
		monthlySummaries: ms,
		mode:             ModeDailyView,
		viewportHeight:   20,
		viewportWidth:    80,
	}
}

func (m Model) Init() tea.Cmd {
	return nil
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		return m.handleKeyPress(msg)
	case tea.WindowSizeMsg:
		m.viewportHeight = msg.Height - 6
		m.viewportWidth = msg.Width
		return m, nil
	case editorFinishedMsg:
		return m.handleEditorFinished(msg)
	case summaryFinishedMsg:
		if msg.summary != nil {
			m.db.SetSummary(msg.date, *msg.summary)
			m.monthlySummaries.SetSummary(msg.date, *msg.summary)
		}
		return m, nil
	}
	return m, nil
}

type editorFinishedMsg struct {
	result *EntryResult
	isNew  bool
	editID string
}

func (m Model) handleKeyPress(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	key := msg.String()

	// Global quit
	if key == "q" {
		m.shouldQuit = true
		return m, tea.Quit
	}

	switch m.mode {
	case ModeDailyView:
		return m.handleDailyViewKeys(key)
	case ModeEntryView:
		return m.handleEntryViewKeys(key)
	case ModeSelectEntry:
		return m.handleSelectEntryKeys(key)
	case ModeConfirmDelete:
		return m.handleConfirmDeleteKeys(key)
	case ModeDaySearchView:
		return m.handleDaySearchKeys(msg)
	case ModeGlobalSearch:
		return m.handleGlobalSearchKeys(msg)
	}

	return m, nil
}

func (m Model) handleDailyViewKeys(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "j":
		m.currentDate = m.currentDate.AddDate(0, 0, 1)
		m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
		m.scrollOffset = 0
		m.daySearchQuery = ""
	case "k":
		m.currentDate = m.currentDate.AddDate(0, 0, -1)
		m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
		m.scrollOffset = 0
		m.daySearchQuery = ""
	case "t":
		m.currentDate = time.Now()
		m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
		m.scrollOffset = 0
		m.daySearchQuery = ""
	case "ctrl+n":
		m.currentDate = m.currentDate.AddDate(0, 1, 0)
		m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
		m.scrollOffset = 0
	case "ctrl+p":
		m.currentDate = m.currentDate.AddDate(0, -1, 0)
		m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
		m.scrollOffset = 0
	case "enter":
		m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
		if len(m.entries) == 0 {
			return m.openNewEntryEditor()
		}
		m.selectedIndex = 0
		m.mode = ModeSelectEntry
	case "/":
		m.daySearchQuery = ""
		m.mode = ModeDaySearchView
	case "s":
		m.searchQuery = ""
		m.searchResults = nil
		m.selectedSearchIndex = 0
		m.mode = ModeGlobalSearch
	case "i", "S":
		return m.openSummaryEditor()
	case "d":
		m.scrollOffset++
	case "u":
		if m.scrollOffset > 0 {
			m.scrollOffset--
		}
	case "ctrl+d":
		m.scrollOffset += m.viewportHeight
	case "ctrl+u":
		if m.scrollOffset >= m.viewportHeight {
			m.scrollOffset -= m.viewportHeight
		} else {
			m.scrollOffset = 0
		}
	}
	return m, nil
}

func (m Model) handleSelectEntryKeys(key string) (tea.Model, tea.Cmd) {
	entries := m.getFilteredEntries()

	switch key {
	case "j", "down":
		if len(entries) > 0 && m.selectedIndex < len(entries)-1 {
			m.selectedIndex++
		}
	case "k", "up":
		if m.selectedIndex > 0 {
			m.selectedIndex--
		}
	case "enter":
		m.mode = ModeEntryView
		m.returnToSelection = true
		idx := m.selectedIndex
		m.prevSelectedIndex = &idx
	case "n":
		return m.openNewEntryEditor()
	case "x":
		m.confirmFromSelection = true
		m.mode = ModeConfirmDelete
	case "esc":
		m.mode = ModeDailyView
	}
	return m, nil
}

func (m Model) handleEntryViewKeys(key string) (tea.Model, tea.Cmd) {
	// Handle numeric keys for opening links
	if len(key) == 1 && key[0] >= '1' && key[0] <= '9' {
		idx := int(key[0] - '1')
		if idx < len(m.lastRenderedLinks) {
			openURL(m.lastRenderedLinks[idx])
		}
		return m, nil
	}
	if key == "0" && len(m.lastRenderedLinks) >= 10 {
		openURL(m.lastRenderedLinks[9])
		return m, nil
	}

	switch key {
	case "j", "down":
		if !m.returnToSelection {
			entries := m.getFilteredEntries()
			if len(entries) > 0 && m.selectedIndex < len(entries)-1 {
				m.selectedIndex++
			}
		}
	case "k", "up":
		if !m.returnToSelection && m.selectedIndex > 0 {
			m.selectedIndex--
		}
	case "enter":
		return m.openEditEntryEditor()
	case "n":
		return m.openNewEntryEditor()
	case "x":
		m.mode = ModeConfirmDelete
	case "esc":
		if m.returnToSelection {
			m.mode = ModeSelectEntry
			if m.prevSelectedIndex != nil {
				m.selectedIndex = *m.prevSelectedIndex
			}
			m.returnToSelection = false
		} else {
			m.mode = ModeDailyView
		}
	case "d":
		m.scrollOffset++
	case "u":
		if m.scrollOffset > 0 {
			m.scrollOffset--
		}
	case "ctrl+d":
		m.scrollOffset += m.viewportHeight
	case "ctrl+u":
		if m.scrollOffset >= m.viewportHeight {
			m.scrollOffset -= m.viewportHeight
		} else {
			m.scrollOffset = 0
		}
	}
	return m, nil
}

func (m Model) handleConfirmDeleteKeys(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "y", "enter":
		entries := m.getFilteredEntries()
		if m.selectedIndex < len(entries) {
			entry := entries[m.selectedIndex]
			m.db.DeleteEntry(entry.ID)
		}
		m.entries, _ = m.db.GetEntriesForDate(m.currentDate)

		if len(m.entries) == 0 {
			m.mode = ModeDailyView
		} else {
			if m.selectedIndex >= len(m.entries) {
				m.selectedIndex = len(m.entries) - 1
			}
			if m.confirmFromSelection {
				m.mode = ModeSelectEntry
				m.confirmFromSelection = false
			} else {
				m.mode = ModeEntryView
			}
		}
	case "n", "esc":
		if m.confirmFromSelection {
			m.mode = ModeSelectEntry
			m.confirmFromSelection = false
		} else {
			m.mode = ModeEntryView
		}
	}
	return m, nil
}

func (m Model) handleDaySearchKeys(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "esc":
		m.daySearchQuery = ""
		m.mode = ModeDailyView
	case "enter":
		m.mode = ModeDailyView
	case "backspace":
		if len(m.daySearchQuery) > 0 {
			m.daySearchQuery = m.daySearchQuery[:len(m.daySearchQuery)-1]
		}
	default:
		if len(msg.String()) == 1 {
			m.daySearchQuery += msg.String()
		}
	}
	return m, nil
}

func (m Model) handleGlobalSearchKeys(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "esc":
		m.searchQuery = ""
		m.searchResults = nil
		m.mode = ModeDailyView
	case "enter":
		// Jump to selected result
		if len(m.searchResults) > 0 && m.selectedSearchIndex < len(m.searchResults) {
			result := m.searchResults[m.selectedSearchIndex]
			m.currentDate = result.Date
			m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
			m.selectedIndex = result.EntryIndex
			if m.selectedIndex >= len(m.entries) {
				m.selectedIndex = 0
			}
			m.daySearchQuery = ""
			m.mode = ModeSelectEntry
		} else {
			m.mode = ModeDailyView
		}
	case "ctrl+n", "down", "j":
		if len(m.searchResults) > 0 && m.selectedSearchIndex < len(m.searchResults)-1 {
			m.selectedSearchIndex++
		}
	case "ctrl+p", "up", "k":
		if m.selectedSearchIndex > 0 {
			m.selectedSearchIndex--
		}
	case "backspace":
		if len(m.searchQuery) > 0 {
			m.searchQuery = m.searchQuery[:len(m.searchQuery)-1]
			m.searchResults, _ = m.db.SearchEntries(m.searchQuery)
			m.selectedSearchIndex = 0
		}
	default:
		if len(msg.String()) == 1 {
			m.searchQuery += msg.String()
			m.searchResults, _ = m.db.SearchEntries(m.searchQuery)
			m.selectedSearchIndex = 0
		}
	}
	return m, nil
}

func (m Model) handleEditorFinished(msg editorFinishedMsg) (tea.Model, tea.Cmd) {
	if msg.result == nil {
		return m, nil
	}

	date, _ := time.Parse("2006-01-02", msg.result.Date)
	t, _ := time.Parse("15:04:05", msg.result.Time)

	if msg.isNew {
		entry := LogEntry{
			ID:       generateULID(),
			Date:     date,
			Time:     t,
			Location: msg.result.Location,
			Tag:      msg.result.Tag,
			Title:    msg.result.Title,
			Content:  msg.result.Content,
		}
		m.db.SaveEntry(&entry)
		m.currentDate = date
	} else {
		entry := LogEntry{
			ID:       msg.editID,
			Date:     date,
			Time:     t,
			Location: msg.result.Location,
			Tag:      msg.result.Tag,
			Title:    msg.result.Title,
			Content:  msg.result.Content,
		}
		m.db.UpdateEntry(&entry)
	}

	m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
	return m, nil
}

func (m Model) openNewEntryEditor() (tea.Model, tea.Cmd) {
	var lastLoc *string
	if len(m.entries) > 0 {
		loc := m.entries[len(m.entries)-1].Location
		lastLoc = &loc
	}

	// Create temp file first
	tmpFile, err := CreateNewEntryTempFile(lastLoc, nil, m.currentDate)
	if err != nil {
		return m, nil
	}

	editor := getEditor()
	cmd := exec.Command(editor, tmpFile)

	return m, tea.ExecProcess(cmd, func(err error) tea.Msg {
		if err != nil {
			os.Remove(tmpFile)
			return editorFinishedMsg{result: nil, isNew: true}
		}

		content, err := os.ReadFile(tmpFile)
		os.Remove(tmpFile)
		if err != nil {
			return editorFinishedMsg{result: nil, isNew: true}
		}

		result, _ := parseYAMLFrontmatter(string(content), m.currentDate.Format("2006-01-02"), time.Now().Format("15:04:05"))
		return editorFinishedMsg{result: result, isNew: true}
	})
}

func (m Model) openEditEntryEditor() (tea.Model, tea.Cmd) {
	entries := m.getFilteredEntries()
	if m.selectedIndex >= len(entries) {
		return m, nil
	}
	entry := entries[m.selectedIndex]

	// Create temp file first
	tmpFile, err := CreateEditEntryTempFile(
		entry.Date.Format("2006-01-02"),
		entry.Time.Format("15:04:05"),
		entry.Location,
		entry.Content,
		entry.Tag,
		entry.Title,
	)
	if err != nil {
		return m, nil
	}

	editor := getEditor()
	cmd := exec.Command(editor, tmpFile)
	editID := entry.ID
	dateStr := entry.Date.Format("2006-01-02")
	timeStr := entry.Time.Format("15:04:05")

	return m, tea.ExecProcess(cmd, func(err error) tea.Msg {
		if err != nil {
			os.Remove(tmpFile)
			return editorFinishedMsg{result: nil, isNew: false, editID: editID}
		}

		content, err := os.ReadFile(tmpFile)
		os.Remove(tmpFile)
		if err != nil {
			return editorFinishedMsg{result: nil, isNew: false, editID: editID}
		}

		result, _ := parseYAMLFrontmatter(string(content), dateStr, timeStr)
		return editorFinishedMsg{result: result, isNew: false, editID: editID}
	})
}

func (m Model) openSummaryEditor() (tea.Model, tea.Cmd) {
	current := m.monthlySummaries.GetSummary(m.currentDate)

	// Create temp file
	tmpFile, err := CreateSummaryTempFile(m.currentDate, current)
	if err != nil {
		return m, nil
	}

	editor := getEditor()
	cmd := exec.Command(editor, tmpFile)
	date := m.currentDate

	return m, tea.ExecProcess(cmd, func(err error) tea.Msg {
		if err != nil {
			os.Remove(tmpFile)
			return summaryFinishedMsg{summary: nil}
		}

		content, err := os.ReadFile(tmpFile)
		os.Remove(tmpFile)
		if err != nil {
			return summaryFinishedMsg{summary: nil}
		}

		lines := strings.Split(string(content), "\n")
		var body string
		if len(lines) > 0 && strings.HasPrefix(strings.TrimSpace(lines[0]), "#") {
			body = strings.TrimSpace(strings.Join(lines[1:], "\n"))
		} else {
			body = strings.TrimSpace(string(content))
		}

		return summaryFinishedMsg{summary: &body, date: date}
	})
}

type summaryFinishedMsg struct {
	summary *string
	date    time.Time
}

func (m Model) getFilteredEntries() []LogEntry {
	switch m.currentTagFilter {
	case TagFilterAll:
		return m.entries
	case TagFilterTag:
		var filtered []LogEntry
		for _, e := range m.entries {
			if e.Tag != nil && *e.Tag == m.filterTag {
				filtered = append(filtered, e)
			}
		}
		return filtered
	case TagFilterUntagged:
		var filtered []LogEntry
		for _, e := range m.entries {
			if e.Tag == nil {
				filtered = append(filtered, e)
			}
		}
		return filtered
	}
	return m.entries
}

func (m Model) View() string {
	switch m.mode {
	case ModeDailyView:
		return m.renderDailyView()
	case ModeEntryView:
		return m.renderEntryView()
	case ModeSelectEntry:
		return m.renderSelectEntry()
	case ModeConfirmDelete:
		base := m.renderSelectEntry()
		if !m.confirmFromSelection {
			base = m.renderEntryView()
		}
		return base + "\n" + m.renderConfirmModal()
	case ModeDaySearchView:
		return m.renderDaySearchView()
	case ModeGlobalSearch:
		return m.renderGlobalSearch()
	}
	return ""
}

// renderBox renders content inside a bordered box of the given dimensions
func renderBox(content string, width, height int) string {
	lines := strings.Split(content, "\n")

	// Build the box
	var result []string

	// Top border
	innerWidth := width - 2
	if innerWidth < 0 {
		innerWidth = 0
	}
	result = append(result, "┌"+strings.Repeat("─", innerWidth)+"┐")

	// Content lines (height - 2 for top/bottom borders)
	contentHeight := height - 2
	for i := 0; i < contentHeight; i++ {
		var line string
		if i < len(lines) {
			line = lines[i]
		}
		// Pad or truncate to fit
		visibleLen := lipgloss.Width(line)
		if visibleLen > innerWidth {
			// Truncate - this is approximate for ANSI strings
			line = truncateString(line, innerWidth)
			visibleLen = lipgloss.Width(line)
		}
		padding := innerWidth - visibleLen
		if padding < 0 {
			padding = 0
		}
		result = append(result, "│"+line+strings.Repeat(" ", padding)+"│")
	}

	// Bottom border
	result = append(result, "└"+strings.Repeat("─", innerWidth)+"┘")

	return strings.Join(result, "\n")
}

func truncateString(s string, maxWidth int) string {
	// Simple truncation that tries to handle ANSI codes
	visible := 0
	result := ""
	inEscape := false

	for _, r := range s {
		if r == '\x1b' {
			inEscape = true
			result += string(r)
			continue
		}
		if inEscape {
			result += string(r)
			if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') {
				inEscape = false
			}
			continue
		}

		if visible >= maxWidth-3 && maxWidth > 3 {
			result += "..."
			break
		}
		result += string(r)
		visible++
	}
	return result
}

func (m Model) renderHeader() string {
	monthName := m.currentDate.Format("January")
	dateStr := m.currentDate.Format("2006-01-02 Monday")

	modeLabel := "Select Date"
	switch m.mode {
	case ModeSelectEntry:
		modeLabel = "Select Entry"
	case ModeEntryView:
		modeLabel = "View Entry"
	case ModeConfirmDelete:
		modeLabel = "Confirm"
	case ModeDaySearchView:
		modeLabel = "Day Search"
	case ModeGlobalSearch:
		modeLabel = "Search"
	}

	// Tag indicator
	tagIndicator := ""
	switch m.currentTagFilter {
	case TagFilterTag:
		tagIndicator = fmt.Sprintf("  [#%s]", m.filterTag)
	case TagFilterUntagged:
		tagIndicator = "  [untagged]"
	}

	left := selectedStyle.Render(monthName)
	center := headerStyle.Render(dateStr + tagIndicator)
	right := modeStyle.Render(modeLabel)

	// Calculate inner width (subtract 2 for left/right borders, 4 for padding)
	innerWidth := m.viewportWidth - 6
	if innerWidth < 10 {
		innerWidth = 10
	}

	leftWidth := lipgloss.Width(left)
	rightWidth := lipgloss.Width(right)
	centerWidth := lipgloss.Width(center)

	// Position: left at start, center in middle, right at end
	leftPad := (innerWidth - centerWidth) / 2
	if leftPad < leftWidth+1 {
		leftPad = leftWidth + 1
	}
	leftPad -= leftWidth

	rightPad := innerWidth - leftWidth - leftPad - centerWidth - rightWidth
	if rightPad < 1 {
		rightPad = 1
	}

	content := "  " + left + strings.Repeat(" ", leftPad) + center + strings.Repeat(" ", rightPad) + right
	return content
}

func (m Model) renderDailyView() string {
	// Layout: header (3 rows) | content (remaining) | footer (3 rows)
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	// Width calculations: 30% left, 70% right
	leftWidth := m.viewportWidth * 30 / 100
	rightWidth := m.viewportWidth - leftWidth

	// Get content for panes
	summaryContent := m.renderSummaryPane(leftWidth - 4)
	entriesContent := m.renderEntriesPane(rightWidth - 4)

	// Build header box
	headerBox := renderBox(m.renderHeader(), m.viewportWidth, headerHeight)

	// Build left pane (summary) - full box
	leftBox := renderBox(summaryContent, leftWidth, contentHeight)

	// Build right pane (entries) - full box
	rightBox := renderBox(entriesContent, rightWidth, contentHeight)

	// Build footer box
	footerBox := renderBox(m.renderFooter(), m.viewportWidth, footerHeight)

	// Combine left and right panes line by line
	leftLines := strings.Split(leftBox, "\n")
	rightLines := strings.Split(rightBox, "\n")

	var contentLines []string
	for i := 0; i < len(leftLines) || i < len(rightLines); i++ {
		var left, right string
		if i < len(leftLines) {
			left = leftLines[i]
		}
		if i < len(rightLines) {
			right = rightLines[i]
		}
		contentLines = append(contentLines, left+right)
	}

	return headerBox + "\n" + strings.Join(contentLines, "\n") + "\n" + footerBox
}

func (m Model) renderSummaryPane(width int) string {
	var lines []string

	year := m.currentDate.Year()
	month := m.currentDate.Month()

	for day := 1; day <= 31; day++ {
		date := time.Date(year, month, day, 0, 0, 0, 0, time.Local)
		if date.Month() != month {
			break
		}

		dayAbbr := date.Format("Mon")[:2]
		summary := m.monthlySummaries.GetSummary(date)
		isCurrent := date.Format("2006-01-02") == m.currentDate.Format("2006-01-02")

		marker := "  "
		if isCurrent {
			marker = "❯ "
		}

		dateText := fmt.Sprintf("%02d %s", day, dayAbbr)
		if isCurrent {
			dateText = selectedStyle.Render(dateText)
		} else if summary == "" {
			dateText = dimStyle.Render(dateText)
		}

		line := marker + dateText
		if summary != "" {
			summaryText := summary
			if len(summaryText) > width-15 {
				summaryText = summaryText[:width-18] + "..."
			}
			if isCurrent {
				summaryText = selectedStyle.Render(summaryText)
			}
			line += " " + summaryText
		}
		lines = append(lines, line)

		// Add blank after Sunday
		if date.Weekday() == time.Sunday && day < 31 {
			lines = append(lines, "")
		}
	}

	return strings.Join(lines, "\n")
}

func (m Model) renderEntriesPane(width int) string {
	entries := m.getFilteredEntries()

	if len(entries) == 0 {
		return dimStyle.Render("No entries for this day")
	}

	var lines []string
	for i, entry := range entries {
		hasTime := entry.Time.Format("15:04:05") != "00:00:00"

		preview := entry.Content
		if entry.Title != nil && *entry.Title != "" {
			preview = *entry.Title
		} else {
			if idx := strings.Index(preview, "\n"); idx != -1 {
				preview = preview[:idx]
			}
		}

		var line string
		if hasTime {
			timeStr := entry.Time.Format("15:04:05")
			if m.mode == ModeSelectEntry && i == m.selectedIndex {
				timeStr = selectedStyle.Render(timeStr)
			}
			line = timeStr + " "

			if entry.Tag != nil {
				line += tagStyle.Render(fmt.Sprintf("[%s]", *entry.Tag)) + " "
			}
		}

		// Highlight search matches
		if m.daySearchQuery != "" && strings.Contains(strings.ToLower(preview), strings.ToLower(m.daySearchQuery)) {
			// Simple highlight - could be improved
			preview = strings.ReplaceAll(preview, m.daySearchQuery, lipgloss.NewStyle().Background(lipgloss.Color("11")).Foreground(lipgloss.Color("0")).Render(m.daySearchQuery))
		}

		line += preview
		if len(line) > width-4 {
			line = line[:width-7] + "..."
		}

		lines = append(lines, " "+line)
	}

	return strings.Join(lines, "\n")
}

func (m Model) renderSelectEntry() string {
	// Layout: header (3) | content (summary 30% | right: list 30% + preview 70%) | footer (3)
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	// Width: 30% left (summary), 70% right (list+preview)
	leftWidth := m.viewportWidth * 30 / 100
	rightWidth := m.viewportWidth - leftWidth

	// Right pane splits vertically: 30% list, 70% preview
	listHeight := contentHeight * 30 / 100
	if listHeight < 3 {
		listHeight = 3
	}
	previewHeight := contentHeight - listHeight

	// Get content
	summaryContent := m.renderSummaryPane(leftWidth - 4)
	listContent := m.renderEntryList(rightWidth - 4, listHeight - 2)
	previewContent := m.renderEntryPreview(rightWidth - 4, previewHeight - 2)

	// Build header and footer
	headerBox := renderBox(m.renderHeader(), m.viewportWidth, headerHeight)
	footerBox := renderBox(m.renderFooter(), m.viewportWidth, footerHeight)

	// Build left pane (full height summary)
	leftBox := renderBox(summaryContent, leftWidth, contentHeight)

	// Build right pane: list on top, preview on bottom (stacked boxes)
	listBox := renderBox(listContent, rightWidth, listHeight)
	previewBox := renderBox(previewContent, rightWidth, previewHeight)

	// Stack list and preview vertically on the right
	rightBox := listBox + "\n" + previewBox

	// Combine left with right
	leftLines := strings.Split(leftBox, "\n")
	rightLines := strings.Split(rightBox, "\n")

	var contentLines []string
	maxLines := len(leftLines)
	if len(rightLines) > maxLines {
		maxLines = len(rightLines)
	}

	for i := 0; i < maxLines; i++ {
		var left, right string
		if i < len(leftLines) {
			left = leftLines[i]
		} else {
			// Continue the left border if we have more right content
			left = "│" + strings.Repeat(" ", leftWidth-2) + "│"
		}
		if i < len(rightLines) {
			right = rightLines[i]
		}
		contentLines = append(contentLines, left+right)
	}

	return headerBox + "\n" + strings.Join(contentLines, "\n") + "\n" + footerBox
}

func (m Model) renderEntryList(width, height int) string {
	entries := m.getFilteredEntries()

	if len(entries) == 0 {
		return dimStyle.Render("No entries. Press n to create one.")
	}

	var lines []string
	for i, entry := range entries {
		if i >= height {
			break
		}

		marker := "  "
		if i == m.selectedIndex {
			marker = dimStyle.Render("❯ ")
		}

		timeStr := entry.Time.Format("15:04:05")
		if i == m.selectedIndex {
			timeStr = selectedStyle.Render(timeStr)
		}

		preview := entry.Content
		if entry.Title != nil && *entry.Title != "" {
			preview = *entry.Title
		} else if idx := strings.Index(preview, "\n"); idx != -1 {
			preview = preview[:idx]
		}

		line := marker + timeStr
		if entry.Tag != nil {
			line += " " + tagStyle.Render(fmt.Sprintf("[%s]", *entry.Tag))
		}
		line += " " + preview

		if lipgloss.Width(line) > width {
			line = truncateString(line, width)
		}

		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

func (m Model) renderEntryPreview(width, height int) string {
	entries := m.getFilteredEntries()

	if len(entries) == 0 || m.selectedIndex >= len(entries) {
		return dimStyle.Render("No preview available")
	}

	entry := entries[m.selectedIndex]
	contentLines := strings.Split(entry.Content, "\n")

	var lines []string
	for i, line := range contentLines {
		if i >= height {
			break
		}
		if lipgloss.Width(line) > width-2 {
			line = truncateString(line, width-2)
		}
		lines = append(lines, " "+line)
	}

	return strings.Join(lines, "\n")
}

func (m Model) renderEntryView() string {
	// Layout: header (3) | content (summary 30% | detail 70%) | footer (3)
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	leftWidth := m.viewportWidth * 30 / 100
	rightWidth := m.viewportWidth - leftWidth

	// Get content
	summaryContent := m.renderSummaryPane(leftWidth - 4)
	detailContent := m.renderEntryDetail(rightWidth - 4, contentHeight - 2)

	// Build boxes
	headerBox := renderBox(m.renderHeader(), m.viewportWidth, headerHeight)
	footerBox := renderBox(m.renderFooter(), m.viewportWidth, footerHeight)

	leftBox := renderBox(summaryContent, leftWidth, contentHeight)
	rightBox := renderBox(detailContent, rightWidth, contentHeight)

	// Combine
	leftLines := strings.Split(leftBox, "\n")
	rightLines := strings.Split(rightBox, "\n")

	var contentLines []string
	maxLines := len(leftLines)
	if len(rightLines) > maxLines {
		maxLines = len(rightLines)
	}

	for i := 0; i < maxLines; i++ {
		var left, right string
		if i < len(leftLines) {
			left = leftLines[i]
		}
		if i < len(rightLines) {
			right = rightLines[i]
		}
		contentLines = append(contentLines, left+right)
	}

	return headerBox + "\n" + strings.Join(contentLines, "\n") + "\n" + footerBox
}

func (m *Model) renderEntryDetail(width, height int) string {
	entries := m.getFilteredEntries()

	if len(entries) == 0 || m.selectedIndex >= len(entries) {
		return dimStyle.Render("No entries for this day. Press n to create one.")
	}

	entry := entries[m.selectedIndex]

	// Title line
	titleLine := selectedStyle.Render(entry.Time.Format("15:04:05"))
	if entry.Tag != nil {
		titleLine += " " + tagStyle.Render(fmt.Sprintf("[%s]", *entry.Tag))
	}
	if entry.Title != nil && *entry.Title != "" {
		titleLine += " " + *entry.Title
	}

	var lines []string
	lines = append(lines, " "+titleLine)
	lines = append(lines, "")

	// Content with link detection
	m.lastRenderedLinks = nil
	contentLines := strings.Split(entry.Content, "\n")
	linkIndex := 1

	for i, line := range contentLines {
		if i >= height-3 {
			break
		}

		// Link detection [text](url)
		rendered := line
		for strings.Contains(rendered, "](") {
			start := strings.Index(rendered, "[")
			mid := strings.Index(rendered, "](")
			end := strings.Index(rendered[mid:], ")")
			if start != -1 && mid != -1 && end != -1 {
				label := rendered[start+1 : mid]
				url := rendered[mid+2 : mid+end]
				m.lastRenderedLinks = append(m.lastRenderedLinks, url)

				linkStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("12")).Underline(true)
				linkText := linkStyle.Render(fmt.Sprintf("%s [%d]", label, linkIndex))
				rendered = rendered[:start] + linkText + rendered[mid+end+1:]
				linkIndex++
			} else {
				break
			}
		}

		if lipgloss.Width(rendered) > width-2 {
			rendered = truncateString(rendered, width-2)
		}
		lines = append(lines, " "+rendered)
	}

	return strings.Join(lines, "\n")
}

func (m Model) renderConfirmModal() string {
	msg := "Delete this entry? Press y to confirm or n/Esc to cancel"
	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("9")).
		Padding(1, 2).
		Render(msg)
}

func (m Model) renderDaySearchView() string {
	// Layout: header (3) | content (summary 50% | entries 50%) | search input (3)
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	leftWidth := m.viewportWidth * 50 / 100
	rightWidth := m.viewportWidth - leftWidth

	// Get content
	summaryContent := m.renderSummaryPane(leftWidth - 4)
	entriesContent := m.renderEntriesPane(rightWidth - 4)

	// Build boxes
	headerBox := renderBox(m.renderHeader(), m.viewportWidth, headerHeight)

	leftBox := renderBox(summaryContent, leftWidth, contentHeight)
	rightBox := renderBox(entriesContent, rightWidth, contentHeight)

	// Search input footer
	searchLine := fmt.Sprintf("Search day: %s_", m.daySearchQuery)
	searchContent := "  " + selectedStyle.Render(searchLine)
	footerBox := renderBox(searchContent, m.viewportWidth, footerHeight)

	// Combine left and right
	leftLines := strings.Split(leftBox, "\n")
	rightLines := strings.Split(rightBox, "\n")

	var contentLines []string
	maxLines := len(leftLines)
	if len(rightLines) > maxLines {
		maxLines = len(rightLines)
	}

	for i := 0; i < maxLines; i++ {
		var left, right string
		if i < len(leftLines) {
			left = leftLines[i]
		}
		if i < len(rightLines) {
			right = rightLines[i]
		}
		contentLines = append(contentLines, left+right)
	}

	return headerBox + "\n" + strings.Join(contentLines, "\n") + "\n" + footerBox
}

func (m Model) renderFooter() string {
	var help string
	switch m.mode {
	case ModeDailyView:
		help = "[j/k] day  [^n/^p] month  [Enter] open  [s] search  [/] filter  [t] today  [i] summary  [q] quit"
	case ModeSelectEntry:
		help = "[j/k] navigate  [Enter] open  [n] new  [x] delete  [Esc] cancel"
	case ModeEntryView:
		help = "[j/k] next/prev  [Enter] edit  [n] new  [x] delete  [Esc] back"
	case ModeConfirmDelete:
		help = "[y/Enter] confirm  [n/Esc] cancel"
	case ModeDaySearchView:
		help = "Type to filter  Enter:keep  Esc:cancel"
	case ModeGlobalSearch:
		help = "[j/k] navigate  [Enter] jump  [Esc] cancel"
	}

	// Center the help text
	helpWidth := lipgloss.Width(help)
	innerWidth := m.viewportWidth - 4
	if innerWidth < 0 {
		innerWidth = 0
	}
	leftPad := (innerWidth - helpWidth) / 2
	if leftPad < 0 {
		leftPad = 0
	}

	return strings.Repeat(" ", leftPad) + dimStyle.Render(help)
}

func padRight(s string, width int) string {
	visibleLen := lipgloss.Width(s)
	if visibleLen >= width {
		return s
	}
	return s + strings.Repeat(" ", width-visibleLen)
}

func openURL(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", url)
	case "windows":
		cmd = exec.Command("cmd", "/C", "start", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	cmd.Start()
}

func (m Model) renderGlobalSearch() string {
	// Layout: search input (3) | results list (remaining) | footer (3)
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	// Search input header
	searchLine := fmt.Sprintf("Search: %s_", m.searchQuery)
	searchContent := "  " + selectedStyle.Render(searchLine)
	headerBox := renderBox(searchContent, m.viewportWidth, headerHeight)

	// Results content
	resultsContent := m.renderSearchResults(m.viewportWidth-4, contentHeight-2)
	resultsBox := renderBox(resultsContent, m.viewportWidth, contentHeight)

	// Footer
	footerBox := renderBox(m.renderFooter(), m.viewportWidth, footerHeight)

	return headerBox + "\n" + resultsBox + "\n" + footerBox
}

func (m Model) renderSearchResults(width, height int) string {
	if len(m.searchResults) == 0 {
		if m.searchQuery == "" {
			return dimStyle.Render("  Type to search across all entries...")
		}
		return dimStyle.Render("  No results found")
	}

	var lines []string
	for i, result := range m.searchResults {
		if i >= height {
			break
		}

		// Get the entry for this result
		entries, _ := m.db.GetEntriesForDate(result.Date)
		var preview string
		if result.EntryIndex < len(entries) {
			entry := entries[result.EntryIndex]
			if entry.Title != nil && *entry.Title != "" {
				preview = *entry.Title
			} else {
				preview = entry.Content
				if idx := strings.Index(preview, "\n"); idx != -1 {
					preview = preview[:idx]
				}
			}
		}

		marker := "  "
		if i == m.selectedSearchIndex {
			marker = dimStyle.Render("❯ ")
		}

		dateStr := result.Date.Format("2006-01-02")
		if i == m.selectedSearchIndex {
			dateStr = selectedStyle.Render(dateStr)
		} else {
			dateStr = tagStyle.Render(dateStr)
		}

		line := marker + dateStr + " " + preview
		if lipgloss.Width(line) > width {
			line = truncateString(line, width)
		}
		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}
