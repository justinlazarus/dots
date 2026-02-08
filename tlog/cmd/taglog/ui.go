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

const (
	modeTagView = iota
	modeEntryView
	modeConfirmDelete
	modeSearch
	modeFilter
)

type Model struct {
	db                *db.Database
	tags              []string
	currentTagIdx     int
	entries           []model.LogEntry
	selectedIndex     int
	scrollOffset      int
	mode              int
	viewportHeight    int
	viewportWidth     int
	shouldQuit        bool
	lastRenderedLinks []string
	filterQuery       string
	searchQuery       string
	searchResults     []searchResult
	searchSelectedIdx int
}

type searchResult struct {
	tag        string
	entryIndex int
	entry      model.LogEntry
}

func NewModel(database *db.Database) Model {
	tags, _ := database.GetAllUniqueTags()
	m := Model{
		db:             database,
		tags:           tags,
		viewportHeight: 20,
		viewportWidth:  80,
	}
	if len(tags) > 0 {
		m.entries, _ = database.GetEntriesByTag(tags[0])
	}
	return m
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

	if key == "q" && m.mode != modeSearch && m.mode != modeFilter {
		m.shouldQuit = true
		return m, tea.Quit
	}

	switch m.mode {
	case modeTagView:
		return m.handleTagViewKeys(key)
	case modeEntryView:
		return m.handleEntryViewKeys(key)
	case modeConfirmDelete:
		return m.handleConfirmDeleteKeys(key)
	case modeSearch:
		return m.handleSearchKeys(msg)
	case modeFilter:
		return m.handleFilterKeys(msg)
	}
	return m, nil
}

func (m Model) handleTagViewKeys(key string) (tea.Model, tea.Cmd) {
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
	case "ctrl+f":
		// Page down in entry list
		pageSize := m.viewportHeight / 2
		if m.selectedIndex+pageSize < len(entries) {
			m.selectedIndex += pageSize
		} else if len(entries) > 0 {
			m.selectedIndex = len(entries) - 1
		}
		m.scrollOffset = 0
	case "ctrl+b":
		// Page up in entry list
		pageSize := m.viewportHeight / 2
		if m.selectedIndex-pageSize >= 0 {
			m.selectedIndex -= pageSize
		} else {
			m.selectedIndex = 0
		}
		m.scrollOffset = 0
	case "ctrl+n":
		if len(m.tags) > 0 {
			m.currentTagIdx = (m.currentTagIdx + 1) % len(m.tags)
			m.entries, _ = m.db.GetEntriesByTag(m.tags[m.currentTagIdx])
			m.selectedIndex = 0
			m.scrollOffset = 0
		}
	case "ctrl+p":
		if len(m.tags) > 0 {
			m.currentTagIdx--
			if m.currentTagIdx < 0 {
				m.currentTagIdx = len(m.tags) - 1
			}
			m.entries, _ = m.db.GetEntriesByTag(m.tags[m.currentTagIdx])
			m.selectedIndex = 0
			m.scrollOffset = 0
		}
	case "enter":
		if len(entries) > 0 {
			m.mode = modeEntryView
			m.scrollOffset = 0
		}
	case "n":
		return m.openNewEntryEditor()
	case "x":
		if len(entries) > 0 {
			m.mode = modeConfirmDelete
		}
	case "s":
		m.searchQuery = ""
		m.searchResults = nil
		m.searchSelectedIdx = 0
		m.mode = modeSearch
	case "/":
		m.mode = modeFilter
	}
	return m, nil
}

func (m Model) handleFilterKeys(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "esc":
		m.filterQuery = ""
		m.selectedIndex = 0
		m.mode = modeTagView
	case "enter":
		m.selectedIndex = 0
		m.mode = modeTagView
	case "backspace":
		if len(m.filterQuery) > 0 {
			m.filterQuery = m.filterQuery[:len(m.filterQuery)-1]
			m.selectedIndex = 0
		}
	default:
		if len(msg.String()) == 1 {
			m.filterQuery += msg.String()
			m.selectedIndex = 0
		}
	}
	return m, nil
}

func (m Model) getFilteredEntries() []model.LogEntry {
	if m.filterQuery == "" {
		return m.entries
	}
	q := strings.ToLower(m.filterQuery)
	var filtered []model.LogEntry
	for _, e := range m.entries {
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

func (m Model) handleEntryViewKeys(key string) (tea.Model, tea.Cmd) {
	// Handle numeric keys for opening links
	if len(key) == 1 && key[0] >= '1' && key[0] <= '9' {
		idx := int(key[0] - '1')
		if idx < len(m.lastRenderedLinks) {
			ui.OpenURL(m.lastRenderedLinks[idx])
		}
		return m, nil
	}

	switch key {
	case "j", "down":
		m.scrollOffset++
	case "k", "up":
		if m.scrollOffset > 0 {
			m.scrollOffset--
		}
	case "ctrl+d":
		m.scrollOffset += m.viewportHeight / 2
	case "ctrl+u":
		half := m.viewportHeight / 2
		if m.scrollOffset >= half {
			m.scrollOffset -= half
		} else {
			m.scrollOffset = 0
		}
	case "enter":
		return m.openEditEntryEditor()
	case "x":
		m.mode = modeConfirmDelete
	case "esc":
		m.mode = modeTagView
		m.scrollOffset = 0
	}
	return m, nil
}

func (m Model) handleConfirmDeleteKeys(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "y", "enter":
		if m.selectedIndex < len(m.entries) {
			entry := m.entries[m.selectedIndex]
			m.db.DeleteEntry(entry.ID)
		}
		// Refresh
		if len(m.tags) > 0 {
			m.entries, _ = m.db.GetEntriesByTag(m.tags[m.currentTagIdx])
		}
		if m.selectedIndex >= len(m.entries) && m.selectedIndex > 0 {
			m.selectedIndex = len(m.entries) - 1
		}
		// If no entries left for this tag, refresh tags
		if len(m.entries) == 0 {
			m.tags, _ = m.db.GetAllUniqueTags()
			if len(m.tags) == 0 {
				m.currentTagIdx = 0
			} else {
				if m.currentTagIdx >= len(m.tags) {
					m.currentTagIdx = len(m.tags) - 1
				}
				m.entries, _ = m.db.GetEntriesByTag(m.tags[m.currentTagIdx])
			}
			m.selectedIndex = 0
		}
		m.mode = modeTagView
	case "n", "esc":
		m.mode = modeTagView
	}
	return m, nil
}

func (m Model) handleSearchKeys(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "esc":
		m.mode = modeTagView
	case "enter":
		if len(m.searchResults) > 0 && m.searchSelectedIdx < len(m.searchResults) {
			r := m.searchResults[m.searchSelectedIdx]
			// Find tag index
			for i, t := range m.tags {
				if t == r.tag {
					m.currentTagIdx = i
					break
				}
			}
			m.entries, _ = m.db.GetEntriesByTag(r.tag)
			// Find the entry index by ID
			for i, e := range m.entries {
				if e.ID == r.entry.ID {
					m.selectedIndex = i
					break
				}
			}
			m.scrollOffset = 0
			m.mode = modeTagView
		} else {
			m.mode = modeTagView
		}
	case "ctrl+n", "down":
		if len(m.searchResults) > 0 && m.searchSelectedIdx < len(m.searchResults)-1 {
			m.searchSelectedIdx++
		}
	case "ctrl+p", "up":
		if m.searchSelectedIdx > 0 {
			m.searchSelectedIdx--
		}
	case "backspace":
		if len(m.searchQuery) > 0 {
			m.searchQuery = m.searchQuery[:len(m.searchQuery)-1]
			m.runSearch()
		}
	default:
		if len(msg.String()) == 1 {
			m.searchQuery += msg.String()
			m.runSearch()
		}
	}
	return m, nil
}

func (m *Model) runSearch() {
	m.searchResults = nil
	m.searchSelectedIdx = 0
	if m.searchQuery == "" {
		return
	}
	q := strings.ToLower(m.searchQuery)
	for _, tag := range m.tags {
		entries, _ := m.db.GetEntriesByTag(tag)
		for idx, e := range entries {
			content := strings.ToLower(e.Content)
			titleMatch := false
			if e.Title != nil {
				titleMatch = strings.Contains(strings.ToLower(*e.Title), q)
			}
			tagMatch := strings.Contains(strings.ToLower(tag), q)
			if strings.Contains(content, q) || titleMatch || tagMatch {
				m.searchResults = append(m.searchResults, searchResult{
					tag:        tag,
					entryIndex: idx,
					entry:      e,
				})
			}
		}
	}
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

	// Refresh tags and entries
	m.tags, _ = m.db.GetAllUniqueTags()
	if len(m.tags) > 0 {
		if m.currentTagIdx >= len(m.tags) {
			m.currentTagIdx = len(m.tags) - 1
		}
		m.entries, _ = m.db.GetEntriesByTag(m.tags[m.currentTagIdx])
	} else {
		m.entries = nil
	}
	if m.selectedIndex >= len(m.entries) && len(m.entries) > 0 {
		m.selectedIndex = len(m.entries) - 1
	}
	return m, nil
}

func (m Model) openNewEntryEditor() (tea.Model, tea.Cmd) {
	var defaultTag *string
	if len(m.tags) > 0 {
		t := m.tags[m.currentTagIdx]
		defaultTag = &t
	}

	tmpFile, err := editor.CreateNewEntryTempFile(nil, defaultTag, time.Now())
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
		result, _ := editor.ParseYAMLFrontmatter(string(content), time.Now().Format("2006-01-02"), time.Now().Format("15:04:05"))
		return editorFinishedMsg{result: result, isNew: true}
	})
}

func (m Model) openEditEntryEditor() (tea.Model, tea.Cmd) {
	if m.selectedIndex >= len(m.entries) {
		return m, nil
	}
	entry := m.entries[m.selectedIndex]

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

// --- View ---

func (m Model) View() string {
	switch m.mode {
	case modeTagView:
		return m.renderTagView()
	case modeEntryView:
		return m.renderFullEntryView()
	case modeConfirmDelete:
		return m.renderTagView() + "\n" + m.renderConfirmModal()
	case modeSearch:
		return m.renderSearchView()
	case modeFilter:
		return m.renderFilterView()
	}
	return ""
}

func (m Model) currentTag() string {
	if len(m.tags) == 0 {
		return "(no tags)"
	}
	return m.tags[m.currentTagIdx]
}

func (m Model) renderHeader() string {
	tagName := m.currentTag()
	tagCount := ""
	if len(m.tags) > 0 {
		tagCount = fmt.Sprintf(" (%d of %d)", m.currentTagIdx+1, len(m.tags))
	}

	modeLabel := "Tag View"
	switch m.mode {
	case modeEntryView:
		modeLabel = "Entry View"
	case modeConfirmDelete:
		modeLabel = "Confirm"
	case modeSearch:
		modeLabel = "Search"
	case modeFilter:
		modeLabel = "Filter"
	}

	filterIndicator := ""
	if m.filterQuery != "" && m.mode != modeFilter {
		filterIndicator = "  " + ui.DimStyle.Render("/"+m.filterQuery)
	}

	left := ui.TagStyle.Render("#"+tagName) + ui.DimStyle.Render(tagCount) + filterIndicator
	right := ui.ModeStyle.Render(modeLabel)

	innerWidth := m.viewportWidth - 6
	if innerWidth < 10 {
		innerWidth = 10
	}

	leftWidth := lipgloss.Width(left)
	rightWidth := lipgloss.Width(right)
	gap := innerWidth - leftWidth - rightWidth
	if gap < 1 {
		gap = 1
	}

	return "  " + left + strings.Repeat(" ", gap) + right
}

func (m Model) renderTagView() string {
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	leftWidth := m.viewportWidth * 40 / 100
	rightWidth := m.viewportWidth - leftWidth

	listContent := m.renderEntryList(leftWidth-4, contentHeight-2)
	detailContent := m.renderEntryDetail(rightWidth-4, contentHeight-2)

	headerBox := ui.RenderBox(m.renderHeader(), m.viewportWidth, headerHeight)
	footerBox := ui.RenderBox(m.renderFooter(), m.viewportWidth, footerHeight)

	leftBox := ui.RenderBox(listContent, leftWidth, contentHeight)
	rightBox := ui.RenderBox(detailContent, rightWidth, contentHeight)

	leftLines := strings.Split(leftBox, "\n")
	rightLines := strings.Split(rightBox, "\n")

	var contentLines []string
	maxLines := len(leftLines)
	if len(rightLines) > maxLines {
		maxLines = len(rightLines)
	}
	for i := 0; i < maxLines; i++ {
		var l, r string
		if i < len(leftLines) {
			l = leftLines[i]
		}
		if i < len(rightLines) {
			r = rightLines[i]
		}
		contentLines = append(contentLines, l+r)
	}

	return headerBox + "\n" + strings.Join(contentLines, "\n") + "\n" + footerBox
}

func (m Model) renderEntryList(width, height int) string {
	entries := m.getFilteredEntries()

	if len(entries) == 0 {
		return ui.DimStyle.Render("  No entries. Press n to create one.")
	}

	// Calculate visible window
	visibleStart := 0
	if m.selectedIndex >= height {
		visibleStart = m.selectedIndex - height + 1
	}

	var lines []string
	for i := visibleStart; i < len(entries) && len(lines) < height; i++ {
		e := entries[i]

		marker := "  "
		if i == m.selectedIndex {
			marker = ui.DimStyle.Render("> ")
		}

		dateStr := e.Date.Format("01/02")
		if i == m.selectedIndex {
			dateStr = ui.SelectedStyle.Render(dateStr)
		} else {
			dateStr = ui.DimStyle.Render(dateStr)
		}

		preview := ""
		if e.Title != nil && *e.Title != "" {
			preview = *e.Title
		} else {
			preview = e.Content
			if idx := strings.Index(preview, "\n"); idx != -1 {
				preview = preview[:idx]
			}
		}

		line := marker + dateStr + " " + preview
		if lipgloss.Width(line) > width {
			line = ui.TruncateString(line, width)
		}
		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

func (m *Model) renderEntryDetail(width, height int) string {
	entries := m.getFilteredEntries()

	if len(entries) == 0 || m.selectedIndex >= len(entries) {
		return ui.DimStyle.Render("  No entry selected")
	}

	entry := entries[m.selectedIndex]

	// Build all lines first
	var allLines []string

	// Header: time, tag, title
	titleLine := ui.SelectedStyle.Render(entry.Time.Format("15:04:05"))
	if entry.Tag != nil {
		titleLine += " " + ui.TagStyle.Render(fmt.Sprintf("[%s]", *entry.Tag))
	}
	if entry.Title != nil && *entry.Title != "" {
		titleLine += " " + *entry.Title
	}
	allLines = append(allLines, " "+titleLine)

	// Date
	allLines = append(allLines, " "+ui.DimStyle.Render(entry.Date.Format("2006-01-02 Monday")))

	// Location
	if entry.Location != "" {
		allLines = append(allLines, " "+ui.DimStyle.Render("@ "+entry.Location))
	}

	// Metadata
	if len(entry.Metadata) > 0 {
		for k, v := range entry.Metadata {
			allLines = append(allLines, " "+ui.DimStyle.Render(k+": ")+v)
		}
	}

	allLines = append(allLines, "")

	// Content with link extraction and markdown rendering
	processed, links := ui.ExtractLinks(entry.Content)
	m.lastRenderedLinks = links

	rendered := ui.RenderMarkdown(processed, width-2)
	for _, line := range strings.Split(rendered, "\n") {
		allLines = append(allLines, " "+line)
	}

	// Apply scroll offset for right pane detail
	start := m.scrollOffset
	if start > len(allLines) {
		start = len(allLines)
	}
	visible := allLines[start:]
	if len(visible) > height {
		visible = visible[:height]
	}

	return strings.Join(visible, "\n")
}

func (m Model) renderFullEntryView() string {
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	headerBox := ui.RenderBox(m.renderHeader(), m.viewportWidth, headerHeight)
	footerContent := m.renderEntryViewFooter()
	footerBox := ui.RenderBox(footerContent, m.viewportWidth, footerHeight)

	detailContent := m.renderFullDetail(m.viewportWidth-4, contentHeight-2)
	contentBox := ui.RenderBox(detailContent, m.viewportWidth, contentHeight)

	return headerBox + "\n" + contentBox + "\n" + footerBox
}

func (m *Model) renderFullDetail(width, height int) string {
	entries := m.getFilteredEntries()

	if len(entries) == 0 || m.selectedIndex >= len(entries) {
		return ui.DimStyle.Render("  No entry selected")
	}

	entry := entries[m.selectedIndex]

	var allLines []string

	titleLine := ui.SelectedStyle.Render(entry.Time.Format("15:04:05"))
	if entry.Tag != nil {
		titleLine += " " + ui.TagStyle.Render(fmt.Sprintf("[%s]", *entry.Tag))
	}
	if entry.Title != nil && *entry.Title != "" {
		titleLine += " " + *entry.Title
	}
	allLines = append(allLines, " "+titleLine)
	allLines = append(allLines, " "+ui.DimStyle.Render(entry.Date.Format("2006-01-02 Monday")))

	if entry.Location != "" {
		allLines = append(allLines, " "+ui.DimStyle.Render("@ "+entry.Location))
	}

	if len(entry.Metadata) > 0 {
		for k, v := range entry.Metadata {
			allLines = append(allLines, " "+ui.DimStyle.Render(k+": ")+v)
		}
	}

	allLines = append(allLines, "")

	processed, links := ui.ExtractLinks(entry.Content)
	m.lastRenderedLinks = links

	rendered := ui.RenderMarkdown(processed, width-2)
	for _, line := range strings.Split(rendered, "\n") {
		allLines = append(allLines, " "+line)
	}

	start := m.scrollOffset
	if start > len(allLines) {
		start = len(allLines)
	}
	visible := allLines[start:]
	if len(visible) > height {
		visible = visible[:height]
	}

	return strings.Join(visible, "\n")
}

func (m Model) renderSearchView() string {
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	searchLine := fmt.Sprintf("Search: %s_", m.searchQuery)
	searchContent := "  " + ui.SelectedStyle.Render(searchLine)
	headerBox := ui.RenderBox(searchContent, m.viewportWidth, headerHeight)

	resultsContent := m.renderSearchResults(m.viewportWidth-4, contentHeight-2)
	resultsBox := ui.RenderBox(resultsContent, m.viewportWidth, contentHeight)

	footerContent := ui.DimStyle.Render("[^n/^p] navigate  [Enter] jump  [Esc] cancel")
	innerWidth := m.viewportWidth - 4
	helpWidth := lipgloss.Width(footerContent)
	pad := (innerWidth - helpWidth) / 2
	if pad < 0 {
		pad = 0
	}
	footerBox := ui.RenderBox(strings.Repeat(" ", pad)+footerContent, m.viewportWidth, footerHeight)

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
	for i, r := range m.searchResults {
		if i >= height {
			break
		}

		marker := "  "
		if i == m.searchSelectedIdx {
			marker = ui.DimStyle.Render("> ")
		}

		tagStr := ui.TagStyle.Render("[" + r.tag + "]")
		dateStr := r.entry.Date.Format("01/02")
		if i == m.searchSelectedIdx {
			dateStr = ui.SelectedStyle.Render(dateStr)
		} else {
			dateStr = ui.DimStyle.Render(dateStr)
		}

		preview := ""
		if r.entry.Title != nil && *r.entry.Title != "" {
			preview = *r.entry.Title
		} else {
			preview = r.entry.Content
			if idx := strings.Index(preview, "\n"); idx != -1 {
				preview = preview[:idx]
			}
		}

		line := marker + tagStr + " " + dateStr + " " + preview
		if lipgloss.Width(line) > width {
			line = ui.TruncateString(line, width)
		}
		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

func (m Model) renderFilterView() string {
	headerHeight := 3
	footerHeight := 3
	contentHeight := m.viewportHeight + 6 - headerHeight - footerHeight
	if contentHeight < 3 {
		contentHeight = 3
	}

	leftWidth := m.viewportWidth * 40 / 100
	rightWidth := m.viewportWidth - leftWidth

	listContent := m.renderEntryList(leftWidth-4, contentHeight-2)
	detailContent := m.renderEntryDetail(rightWidth-4, contentHeight-2)

	headerBox := ui.RenderBox(m.renderHeader(), m.viewportWidth, headerHeight)

	filterLine := fmt.Sprintf("Filter: %s_", m.filterQuery)
	filterContent := "  " + ui.SelectedStyle.Render(filterLine)
	footerBox := ui.RenderBox(filterContent, m.viewportWidth, footerHeight)

	leftBox := ui.RenderBox(listContent, leftWidth, contentHeight)
	rightBox := ui.RenderBox(detailContent, rightWidth, contentHeight)

	leftLines := strings.Split(leftBox, "\n")
	rightLines := strings.Split(rightBox, "\n")

	var contentLines []string
	maxLines := len(leftLines)
	if len(rightLines) > maxLines {
		maxLines = len(rightLines)
	}
	for i := 0; i < maxLines; i++ {
		var l, r string
		if i < len(leftLines) {
			l = leftLines[i]
		}
		if i < len(rightLines) {
			r = rightLines[i]
		}
		contentLines = append(contentLines, l+r)
	}

	return headerBox + "\n" + strings.Join(contentLines, "\n") + "\n" + footerBox
}

func (m Model) renderConfirmModal() string {
	msg := "Delete this entry? Press y to confirm or n/Esc to cancel"
	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("9")).
		Padding(1, 2).
		Render(msg)
}

func (m Model) renderFooter() string {
	help := "[j/k] entry  [^f/^b] page  [^n/^p] tag  [Enter] view  [n] new  [x] delete  [/] filter  [s] search  [q] quit"

	innerWidth := m.viewportWidth - 4
	helpWidth := lipgloss.Width(help)
	pad := (innerWidth - helpWidth) / 2
	if pad < 0 {
		pad = 0
	}

	return strings.Repeat(" ", pad) + ui.DimStyle.Render(help)
}

func (m Model) renderEntryViewFooter() string {
	help := "[j/k] scroll  [^d/^u] page  [Enter] edit  [x] delete  [Esc] back  [q] quit"

	innerWidth := m.viewportWidth - 4
	helpWidth := lipgloss.Width(help)
	pad := (innerWidth - helpWidth) / 2
	if pad < 0 {
		pad = 0
	}

	return strings.Repeat(" ", pad) + ui.DimStyle.Render(help)
}
