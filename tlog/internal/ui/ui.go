package ui

import (
	"fmt"
	"os/exec"
	"regexp"
	"runtime"
	"strings"

	"github.com/charmbracelet/glamour"
	"github.com/charmbracelet/lipgloss"
)

// Styles
var (
	HeaderStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("15"))

	SelectedStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("11")) // Yellow

	TagStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("14")) // Cyan

	DimStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("8")) // Gray

	BorderStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("8"))

	ModeStyle = lipgloss.NewStyle().
			Bold(true).
			Background(lipgloss.Color("2")).
			Foreground(lipgloss.Color("0")).
			Padding(0, 1)
)

// RenderBox renders content inside a bordered box of the given dimensions
func RenderBox(content string, width, height int) string {
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
			line = TruncateString(line, innerWidth)
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

func TruncateString(s string, maxWidth int) string {
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

func PadRight(s string, width int) string {
	visibleLen := lipgloss.Width(s)
	if visibleLen >= width {
		return s
	}
	return s + strings.Repeat(" ", width-visibleLen)
}

var linkRe = regexp.MustCompile(`\[([^\]]+)\]\(([^)]+)\)`)

// ExtractLinks finds [text](url) patterns, replaces with "text [N]", and collects URLs.
func ExtractLinks(content string) (string, []string) {
	var links []string
	result := linkRe.ReplaceAllStringFunc(content, func(match string) string {
		parts := linkRe.FindStringSubmatch(match)
		if len(parts) < 3 {
			return match
		}
		links = append(links, parts[2])
		return fmt.Sprintf("%s [%d]", parts[1], len(links))
	})
	return result, links
}

// RenderMarkdown renders markdown content to styled terminal output via glamour.
func RenderMarkdown(content string, width int) string {
	r, err := glamour.NewTermRenderer(
		glamour.WithAutoStyle(),
		glamour.WithWordWrap(width),
	)
	if err != nil {
		return content
	}

	out, err := r.Render(content)
	if err != nil {
		return content
	}

	// Trim trailing whitespace glamour adds
	return strings.TrimRight(out, "\n")
}

func OpenURL(url string) {
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
