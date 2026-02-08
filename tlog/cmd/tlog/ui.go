package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"tlog/internal/db"
	"tlog/internal/editor"
	"tlog/internal/model"
	"tlog/internal/ui"
)

// Model is the main application state
type Model struct {
	db               *db.Database
	currentDate      time.Time
	entries          []model.LogEntry
	monthlySummaries *model.MonthlySummaries
	mode             model.AppMode
	scrollOffset     int
	selectedIndex    int
	currentTagFilter model.TagFilter
	filterTag        string
	searchQuery      string
	daySearchQuery   string

	// Global search state
	searchResults       []model.SearchResult
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

func NewModel(database *db.Database) Model {
	today := time.Now()
	entries, _ := database.GetEntriesForDate(today)

	summaries, _ := database.GetAllSummaries()
	ms := model.NewMonthlySummaries()
	ms.Summaries = summaries

	return Model{
		db:               database,
		currentDate:      today,
		entries:          entries,
		monthlySummaries: ms,
		mode:             model.ModeDailyView,
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
	result *editor.EntryResult
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
	case model.ModeDailyView:
		return m.handleDailyViewKeys(key)
	case model.ModeEntryView:
		return m.handleEntryViewKeys(key)
	case model.ModeSelectEntry:
		return m.handleSelectEntryKeys(key)
	case model.ModeConfirmDelete:
		return m.handleConfirmDeleteKeys(key)
	case model.ModeDaySearchView:
		return m.handleDaySearchKeys(msg)
	case model.ModeGlobalSearch:
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
	case "k":
		m.currentDate = m.currentDate.AddDate(0, 0, -1)
		m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
		m.scrollOffset = 0
	case "t":
		m.currentDate = time.Now()
		m.entries, _ = m.db.GetEntriesForDate(m.currentDate)
		m.scrollOffset = 0
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
		m.mode = model.ModeSelectEntry
	case "/":
		m.mode = model.ModeDaySearchView
	case "s":
		m.searchQuery = ""
		m.searchResults = nil
		m.selectedSearchIndex = 0
		m.mode = model.ModeGlobalSearch
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
			m.scrollOffset = 0
		}
	case "k", "up":
		if m.selectedIndex > 0 {
			m.selectedIndex--
			m.scrollOffset = 0
		}
	case "ctrl+n":
		m.scrollOffset++
	case "ctrl+p":
		if m.scrollOffset > 0 {
			m.scrollOffset--
		}
	case "enter":
		m.mode = model.ModeEntryView
		m.returnToSelection = true
		idx := m.selectedIndex
		m.prevSelectedIndex = &idx
	case "n":
		return m.openNewEntryEditor()
	case "x":
		m.confirmFromSelection = true
		m.mode = model.ModeConfirmDelete
	case "esc":
		m.mode = model.ModeDailyView
	}
	return m, nil
}

func (m Model) handleEntryViewKeys(key string) (tea.Model, tea.Cmd) {
	// Handle numeric keys for opening links
	if len(key) == 1 && key[0] >= '1' && key[0] <= '9' {
		idx := int(key[0] - '1')
		if idx < len(m.lastRenderedLinks) {
			ui.OpenURL(m.lastRenderedLinks[idx])
		}
		return m, nil
	}
	if key == "0" && len(m.lastRenderedLinks) >= 10 {
		ui.OpenURL(m.lastRenderedLinks[9])
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
		m.mode = model.ModeConfirmDelete
	case "esc":
		if m.returnToSelection {
			m.mode = model.ModeSelectEntry
			if m.prevSelectedIndex != nil {
				m.selectedIndex = *m.prevSelectedIndex
			}
			m.returnToSelection = false
		} else {
			m.mode = model.ModeDailyView
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
			m.mode = model.ModeDailyView
		} else {
			if m.selectedIndex >= len(m.entries) {
				m.selectedIndex = len(m.entries) - 1
			}
			if m.confirmFromSelection {
				m.mode = model.ModeSelectEntry
				m.confirmFromSelection = false
			} else {
				m.mode = model.ModeEntryView
			}
		}
	case "n", "esc":
		if m.confirmFromSelection {
			m.mode = model.ModeSelectEntry
			m.confirmFromSelection = false
		} else {
			m.mode = model.ModeEntryView
		}
	}
	return m, nil
}

func (m Model) handleDaySearchKeys(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "esc":
		m.daySearchQuery = ""
		m.mode = model.ModeDailyView
	case "enter":
		m.mode = model.ModeDailyView
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
		m.mode = model.ModeDailyView
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
			m.mode = model.ModeSelectEntry
		} else {
			m.mode = model.ModeDailyView
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
		entry := model.LogEntry{
			ID:       model.GenerateULID(),
			Date:     date,
			Time:     t,
			Location: msg.result.Location,
			Tag:      msg.result.Tag,
			Title:    msg.result.Title,
			Content:  msg.result.Content,
			Metadata: msg.result.Metadata,
		}
		m.db.SaveEntry(&entry)
		m.currentDate = date
	} else {
		entry := model.LogEntry{
			ID:       msg.editID,
			Date:     date,
			Time:     t,
			Location: msg.result.Location,
			Tag:      msg.result.Tag,
			Title:    msg.result.Title,
			Content:  msg.result.Content,
			Metadata: msg.result.Metadata,
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
	tmpFile, err := editor.CreateNewEntryTempFile(lastLoc, nil, m.currentDate)
	if err != nil {
		return m, nil
	}

	ed := editor.GetEditor()
	cmd := exec.Command(ed, tmpFile)

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

		result, _ := editor.ParseYAMLFrontmatter(string(content), m.currentDate.Format("2006-01-02"), time.Now().Format("15:04:05"))
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
	tmpFile, err := editor.CreateEditEntryTempFile(
		entry.Date.Format("2006-01-02"),
		entry.Time.Format("15:04:05"),
		entry.Location,
		entry.Content,
		entry.Tag,
		entry.Title,
		entry.Metadata,
	)
	if err != nil {
		return m, nil
	}

	ed := editor.GetEditor()
	cmd := exec.Command(ed, tmpFile)
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

		result, _ := editor.ParseYAMLFrontmatter(string(content), dateStr, timeStr)
		return editorFinishedMsg{result: result, isNew: false, editID: editID}
	})
}

func (m Model) openSummaryEditor() (tea.Model, tea.Cmd) {
	current := m.monthlySummaries.GetSummary(m.currentDate)

	// Create temp file
	tmpFile, err := editor.CreateSummaryTempFile(m.currentDate, current)
	if err != nil {
		return m, nil
	}

	ed := editor.GetEditor()
	cmd := exec.Command(ed, tmpFile)
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

func (m Model) getFilteredEntries() []model.LogEntry {
	var entries []model.LogEntry

	switch m.currentTagFilter {
	case model.TagFilterTag:
		for _, e := range m.entries {
			if e.Tag != nil && *e.Tag == m.filterTag {
				entries = append(entries, e)
			}
		}
	case model.TagFilterUntagged:
		for _, e := range m.entries {
			if e.Tag == nil {
				entries = append(entries, e)
			}
		}
	default:
		entries = m.entries
	}

	if m.daySearchQuery == "" {
		return entries
	}

	q := strings.ToLower(m.daySearchQuery)
	var filtered []model.LogEntry
	for _, e := range entries {
		if entryMatchesFilter(e, q) {
			filtered = append(filtered, e)
		}
	}
	return filtered
}

func entryMatchesFilter(e model.LogEntry, q string) bool {
	if strings.Contains(strings.ToLower(e.Content), q) {
		return true
	}
	if e.Title != nil && strings.Contains(strings.ToLower(*e.Title), q) {
		return true
	}
	if e.Tag != nil && strings.Contains(strings.ToLower(*e.Tag), q) {
		return true
	}
	if strings.Contains(strings.ToLower(e.Location), q) {
		return true
	}
	for k, v := range e.Metadata {
		if strings.Contains(strings.ToLower(k), q) || strings.Contains(strings.ToLower(v), q) {
			return true
		}
	}
	return false
}

func (m Model) View() string {
	switch m.mode {
	case model.ModeDailyView:
		return m.renderDailyView()
	case model.ModeEntryView:
		return m.renderEntryView()
	case model.ModeSelectEntry:
		return m.renderSelectEntry()
	case model.ModeConfirmDelete:
		base := m.renderSelectEntry()
		if !m.confirmFromSelection {
			base = m.renderEntryView()
		}
		return base + "\n" + m.renderConfirmModal()
	case model.ModeDaySearchView:
		return m.renderDaySearchView()
	case model.ModeGlobalSearch:
		return m.renderGlobalSearch()
	}
	return ""
}

func (m Model) renderHeader() string {
	monthName := m.currentDate.Format("January")
	dateStr := m.currentDate.Format("2006-01-02 Monday")

	modeLabel := "Select Date"
	switch m.mode {
	case model.ModeSelectEntry:
		modeLabel = "Select Entry"
	case model.ModeEntryView:
		modeLabel = "View Entry"
	case model.ModeConfirmDelete:
		modeLabel = "Confirm"
	case model.ModeDaySearchView:
		modeLabel = "Filter"
	case model.ModeGlobalSearch:
		modeLabel = "Search"
	}

	// Tag indicator
	tagIndicator := ""
	switch m.currentTagFilter {
	case model.TagFilterTag:
		tagIndicator = fmt.Sprintf("  [#%s]", m.filterTag)
	case model.TagFilterUntagged:
		tagIndicator = "  [untagged]"
	}

	// Filter indicator
	filterIndicator := ""
	if m.daySearchQuery != "" && m.mode != model.ModeDaySearchView {
		filterIndicator = fmt.Sprintf("  /%s", m.daySearchQuery)
	}

	left := ui.SelectedStyle.Render(monthName)
	center := ui.HeaderStyle.Render(dateStr+tagIndicator) + ui.DimStyle.Render(filterIndicator)
	right := ui.ModeStyle.Render(modeLabel)

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
	headerBox := ui.RenderBox(m.renderHeader(), m.viewportWidth, headerHeight)

	// Build left pane (summary) - full box
	leftBox := ui.RenderBox(summaryContent, leftWidth, contentHeight)

	// Build right pane (entries) - full box
	rightBox := ui.RenderBox(entriesContent, rightWidth, contentHeight)

	// Build footer box
	footerBox := ui.RenderBox(m.renderFooter(), m.viewportWidth, footerHeight)

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
			dateText = ui.SelectedStyle.Render(dateText)
		} else if summary == "" {
			dateText = ui.DimStyle.Render(dateText)
		}

		line := marker + dateText
		if summary != "" {
			summaryText := summary
			if len(summaryText) > width-15 {
				summaryText = summaryText[:width-18] + "..."
			}
			if isCurrent {
				summaryText = ui.SelectedStyle.Render(summaryText)
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
		return ui.DimStyle.Render("No entries for this day")
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
			if m.mode == model.ModeSelectEntry && i == m.selectedIndex {
				timeStr = ui.SelectedStyle.Render(timeStr)
			}
			line = timeStr + " "

			if entry.Tag != nil {
				line += ui.TagStyle.Render(fmt.Sprintf("[%s]", *entry.Tag)) + " "
			}
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
	listContent := m.renderEntryList(rightWidth-4, listHeight-2)
	previewContent := m.renderEntryPreview(rightWidth-4, previewHeight-2)

	// Build header and footer
	headerBox := ui.RenderBox(m.renderHeader(), m.viewportWidth, headerHeight)
	footerBox := ui.RenderBox(m.renderFooter(), m.viewportWidth, footerHeight)

	// Build left pane (full height summary)
	leftBox := ui.RenderBox(summaryContent, leftWidth, contentHeight)

	// Build right pane: list on top, preview on bottom (stacked boxes)
	listBox := ui.RenderBox(listContent, rightWidth, listHeight)
	previewBox := ui.RenderBox(previewContent, rightWidth, previewHeight)

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
		return ui.DimStyle.Render("No entries. Press n to create one.")
	}

	var lines []string
	for i, entry := range entries {
		if i >= height {
			break
		}

		marker := "  "
		if i == m.selectedIndex {
			marker = ui.DimStyle.Render("❯ ")
		}

		timeStr := entry.Time.Format("15:04:05")
		if i == m.selectedIndex {
			timeStr = ui.SelectedStyle.Render(timeStr)
		}

		preview := entry.Content
		if entry.Title != nil && *entry.Title != "" {
			preview = *entry.Title
		} else if idx := strings.Index(preview, "\n"); idx != -1 {
			preview = preview[:idx]
		}

		line := marker + timeStr
		if entry.Tag != nil {
			line += " " + ui.TagStyle.Render(fmt.Sprintf("[%s]", *entry.Tag))
		}
		line += " " + preview

		if lipgloss.Width(line) > width {
			line = ui.TruncateString(line, width)
		}

		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

func (m Model) renderEntryPreview(width, height int) string {
	entries := m.getFilteredEntries()

	if len(entries) == 0 || m.selectedIndex >= len(entries) {
		return ui.DimStyle.Render("No preview available")
	}

	entry := entries[m.selectedIndex]
	rendered := ui.RenderMarkdown(entry.Content, width-2)

	allLines := strings.Split(rendered, "\n")

	start := m.scrollOffset
	if start > len(allLines) {
		start = len(allLines)
	}
	visible := allLines[start:]
	if len(visible) > height {
		visible = visible[:height]
	}

	var lines []string
	for _, line := range visible {
		lines = append(lines, " "+line)
	}

	return strings.Join(lines, "\n")
}

func (m Model) renderEntryView() string {
	// Layout: header (3) | full-width detail | footer (3)
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	detailContent := m.renderEntryDetail(m.viewportWidth-4, contentHeight-2)

	headerBox := ui.RenderBox(m.renderHeader(), m.viewportWidth, headerHeight)
	footerBox := ui.RenderBox(m.renderFooter(), m.viewportWidth, footerHeight)
	contentBox := ui.RenderBox(detailContent, m.viewportWidth, contentHeight)

	return headerBox + "\n" + contentBox + "\n" + footerBox
}

func (m *Model) renderEntryDetail(width, height int) string {
	entries := m.getFilteredEntries()

	if len(entries) == 0 || m.selectedIndex >= len(entries) {
		return ui.DimStyle.Render("No entries for this day. Press n to create one.")
	}

	entry := entries[m.selectedIndex]

	// Title line
	titleLine := ui.SelectedStyle.Render(entry.Time.Format("15:04:05"))
	if entry.Tag != nil {
		titleLine += " " + ui.TagStyle.Render(fmt.Sprintf("[%s]", *entry.Tag))
	}
	if entry.Title != nil && *entry.Title != "" {
		titleLine += " " + *entry.Title
	}

	var lines []string
	lines = append(lines, " "+titleLine)

	// Display metadata key/value pairs
	if len(entry.Metadata) > 0 {
		for k, v := range entry.Metadata {
			lines = append(lines, " "+ui.DimStyle.Render(k+": ")+v)
		}
	}

	lines = append(lines, "")

	// Content with link extraction and markdown rendering
	processed, links := ui.ExtractLinks(entry.Content)
	m.lastRenderedLinks = links

	rendered := ui.RenderMarkdown(processed, width-2)
	for _, line := range strings.Split(rendered, "\n") {
		lines = append(lines, " "+line)
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

	leftWidth := m.viewportWidth * 30 / 100
	rightWidth := m.viewportWidth - leftWidth

	// Get content
	summaryContent := m.renderSummaryPane(leftWidth - 4)
	entriesContent := m.renderEntriesPane(rightWidth - 4)

	// Build boxes
	headerBox := ui.RenderBox(m.renderHeader(), m.viewportWidth, headerHeight)

	leftBox := ui.RenderBox(summaryContent, leftWidth, contentHeight)
	rightBox := ui.RenderBox(entriesContent, rightWidth, contentHeight)

	// Search input footer
	searchLine := fmt.Sprintf("Filter: %s_", m.daySearchQuery)
	searchContent := "  " + ui.SelectedStyle.Render(searchLine)
	footerBox := ui.RenderBox(searchContent, m.viewportWidth, footerHeight)

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
	case model.ModeDailyView:
		help = "[j/k] day  [^n/^p] month  [Enter] open  [s] search  [/] filter  [t] today  [i] summary  [q] quit"
	case model.ModeSelectEntry:
		help = "[j/k] navigate  [^n/^p] scroll  [Enter] open  [n] new  [x] delete  [Esc] cancel"
	case model.ModeEntryView:
		help = "[j/k] next/prev  [Enter] edit  [n] new  [x] delete  [Esc] back"
	case model.ModeConfirmDelete:
		help = "[y/Enter] confirm  [n/Esc] cancel"
	case model.ModeDaySearchView:
		help = "Type to filter  [Enter] apply  [Esc] clear"
	case model.ModeGlobalSearch:
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

	return strings.Repeat(" ", leftPad) + ui.DimStyle.Render(help)
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
	searchContent := "  " + ui.SelectedStyle.Render(searchLine)
	headerBox := ui.RenderBox(searchContent, m.viewportWidth, headerHeight)

	// Results content
	resultsContent := m.renderSearchResults(m.viewportWidth-4, contentHeight-2)
	resultsBox := ui.RenderBox(resultsContent, m.viewportWidth, contentHeight)

	// Footer
	footerBox := ui.RenderBox(m.renderFooter(), m.viewportWidth, footerHeight)

	return headerBox + "\n" + resultsBox + "\n" + footerBox
}

func (m Model) renderSearchResults(width, height int) string {
	if len(m.searchResults) == 0 {
		if m.searchQuery == "" {
			return ui.DimStyle.Render("  Type to search across all entries...")
		}
		return ui.DimStyle.Render("  No results found")
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
			marker = ui.DimStyle.Render("❯ ")
		}

		dateStr := result.Date.Format("2006-01-02")
		if i == m.selectedSearchIndex {
			dateStr = ui.SelectedStyle.Render(dateStr)
		} else {
			dateStr = ui.TagStyle.Render(dateStr)
		}

		line := marker + dateStr + " " + preview
		if lipgloss.Width(line) > width {
			line = ui.TruncateString(line, width)
		}
		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}
