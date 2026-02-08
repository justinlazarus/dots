package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/muesli/termenv"

	"tlog/internal/db"
)

func main() {
	lipgloss.SetColorProfile(termenv.TrueColor)

	// Open database
	database, err := db.OpenDatabase("logs.db")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to open database: %v\n", err)
		os.Exit(1)
	}
	defer database.Close()

	// Create model
	m := NewModel(database)

	// Run the TUI
	p := tea.NewProgram(m, tea.WithAltScreen())

	finalModel, err := p.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running program: %v\n", err)
		os.Exit(1)
	}

	// Export to markdown on exit (for git workflow)
	fmt.Println("Syncing database to markdown for git...")
	if fm, ok := finalModel.(Model); ok {
		if err := fm.db.ExportToMarkdown("archive.md"); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to export markdown: %v\n", err)
		}
	}
}
