package main

import (
	"fmt"
	"math/rand"
	"os"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/oklog/ulid/v2"
)

var entropy = ulid.Monotonic(rand.New(rand.NewSource(time.Now().UnixNano())), 0)

func generateULID() string {
	return ulid.MustNew(ulid.Timestamp(time.Now()), entropy).String()
}

func main() {
	// Open database
	db, err := OpenDatabase("logs.db")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to open database: %v\n", err)
		os.Exit(1)
	}
	defer db.Close()

	// Create model
	model := NewModel(db)

	// Run the TUI
	p := tea.NewProgram(model, tea.WithAltScreen())

	finalModel, err := p.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running program: %v\n", err)
		os.Exit(1)
	}

	// Export to markdown on exit (for git workflow)
	fmt.Println("Syncing database to markdown for git...")
	if m, ok := finalModel.(Model); ok {
		if err := m.db.ExportToMarkdown("archive.md"); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to export markdown: %v\n", err)
		}
	}
}
