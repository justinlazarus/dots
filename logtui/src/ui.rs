use crate::models::{AppMode, AppState};
use chrono::{Datelike, NaiveDate};
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, List, ListItem, Paragraph, Wrap},
    Frame,
};

/// Parse a markdown line and return styled spans
fn parse_markdown_line(line: &str) -> Line<'static> {
    let mut spans = Vec::new();
    let chars: Vec<char> = line.chars().collect();
    let mut i = 0;

    // Check for header (# at start)
    if line.starts_with("# ") {
        return Line::from(vec![
            Span::styled(
                line.to_string(),
                Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
            )
        ]);
    }

    while i < chars.len() {
        // Bold: **text**
        if i + 1 < chars.len() && chars[i] == '*' && chars[i + 1] == '*' {
            let start = i + 2;
            let mut end = start;
            while end + 1 < chars.len() {
                if chars[end] == '*' && chars[end + 1] == '*' {
                    let text: String = chars[start..end].iter().collect();
                    spans.push(Span::styled(
                        text,
                        Style::default().add_modifier(Modifier::BOLD),
                    ));
                    i = end + 2;
                    break;
                }
                end += 1;
            }
            if end + 1 >= chars.len() {
                // No closing **, treat as literal
                spans.push(Span::raw("**".to_string()));
                i += 2;
            }
        }
        // Italic: *text*
        else if chars[i] == '*' {
            let start = i + 1;
            let mut end = start;
            while end < chars.len() && chars[end] != '*' {
                end += 1;
            }
            if end < chars.len() {
                let text: String = chars[start..end].iter().collect();
                spans.push(Span::styled(
                    text,
                    Style::default().add_modifier(Modifier::ITALIC),
                ));
                i = end + 1;
            } else {
                spans.push(Span::raw("*".to_string()));
                i += 1;
            }
        }
        // Inline code: `text`
        else if chars[i] == '`' {
            let start = i + 1;
            let mut end = start;
            while end < chars.len() && chars[end] != '`' {
                end += 1;
            }
            if end < chars.len() {
                let text: String = chars[start..end].iter().collect();
                spans.push(Span::styled(
                    text,
                    Style::default().fg(Color::Green),
                ));
                i = end + 1;
            } else {
                spans.push(Span::raw("`".to_string()));
                i += 1;
            }
        }
        // Regular text
        else {
            let mut text = String::new();
            while i < chars.len() && chars[i] != '*' && chars[i] != '`' {
                text.push(chars[i]);
                i += 1;
            }
            if !text.is_empty() {
                spans.push(Span::raw(text));
            }
        }
    }

    if spans.is_empty() {
        Line::from(line.to_string())
    } else {
        Line::from(spans)
    }
}

/// Highlight search matches in text with yellow background
fn highlight_matches(line: &str, query: &str) -> Line<'static> {
    if query.is_empty() {
        return parse_markdown_line(line);
    }
    
    let query_lower = query.to_lowercase();
    let line_lower = line.to_lowercase();
    
    // Find all match positions
    let mut matches: Vec<(usize, usize)> = Vec::new();
    let mut start = 0;
    
    while let Some(pos) = line_lower[start..].find(&query_lower) {
        let absolute_pos = start + pos;
        matches.push((absolute_pos, absolute_pos + query.len()));
        start = absolute_pos + 1;
    }
    
    if matches.is_empty() {
        return parse_markdown_line(line);
    }
    
    // Build spans with highlights
    let mut spans = Vec::new();
    let mut last_end = 0;
    
    for (match_start, match_end) in matches {
        // Add text before match
        if match_start > last_end {
            spans.push(Span::raw(line[last_end..match_start].to_string()));
        }
        
        // Add highlighted match
        spans.push(Span::styled(
            line[match_start..match_end].to_string(),
            Style::default().bg(Color::Yellow).fg(Color::Black),
        ));
        
        last_end = match_end;
    }
    
    // Add remaining text
    if last_end < line.len() {
        spans.push(Span::raw(line[last_end..].to_string()));
    }
    
    Line::from(spans)
}

pub fn render(f: &mut Frame, app: &AppState) {
    match &app.mode {
        AppMode::DailyView => render_daily_view(f, app),
        AppMode::SelectEntry => render_entry_selection(f, app),
        AppMode::CalendarView => render_calendar_view(f, app),
        AppMode::SearchView => render_search_view(f, app),
        AppMode::DaySearchView => render_day_search_view(f, app),
        AppMode::JumpToDate => render_jump_to_date(f, app),
        AppMode::QuickEntry | AppMode::FullEntry | AppMode::EditEntry(_) => {
            // External editor is running, nothing to render
            render_daily_view(f, app)
        }
    }
}

fn render_daily_view(f: &mut Frame, app: &AppState) {
    // Create vertical layout: header row | content row | footer row
    let vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header row (full width)
            Constraint::Min(0),     // Content row (will split horizontally)
            Constraint::Length(3),  // Footer row (full width)
        ])
        .split(f.size());

    // Split content row horizontally (50/50)
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(50), // Summary pane
            Constraint::Percentage(50), // Detail pane
        ])
        .split(vertical_chunks[1]);

    // Header and footer use full width
    let header_area = vertical_chunks[0];
    let footer_area = vertical_chunks[2];

    // Render full-width header
    render_combined_header(f, header_area, app);

    // Render left column (summary pane)
    render_summary_content(f, content_chunks[0], app);

    // Render right column (detail pane)
    render_entries(f, content_chunks[1], app);

    // Render full-width footer (help text)
    render_footer(f, footer_area, app);
}

fn render_combined_header(f: &mut Frame, area: Rect, app: &AppState) {
    // Month name + date
    let month_name = app.current_date.format("%B").to_string(); // Full month name
    let date_str = app.current_date.format("%Y-%m-%d %A").to_string();
    
    // Build tag indicator string
    let mut tag_parts = Vec::new();
    
    // Add "all" at the beginning
    let total_count: usize = app.available_tags.iter().map(|(_, c)| c).sum::<usize>() 
        + app.untagged_count;
    if matches!(app.current_tag_filter, crate::models::TagFilter::All) {
        tag_parts.push(format!("[all: {}]", total_count));
    } else {
        tag_parts.push(format!("all: {}", total_count));
    }
    
    // Add each tag with count
    for (tag, count) in &app.available_tags {
        if matches!(app.current_tag_filter, crate::models::TagFilter::Tag(ref t) if t == tag) {
            tag_parts.push(format!("[{}: {}]", tag, count));
        } else {
            tag_parts.push(format!("{}: {}", tag, count));
        }
    }
    
    // Add untagged if present
    if app.untagged_count > 0 {
        if matches!(app.current_tag_filter, crate::models::TagFilter::Untagged) {
            tag_parts.push(format!("[untagged: {}]", app.untagged_count));
        } else {
            tag_parts.push(format!("untagged: {}", app.untagged_count));
        }
    }
    
    let tag_indicator = if tag_parts.is_empty() {
        String::new()
    } else {
        format!("  {}", tag_parts.join(" "))
    };
    
    // Combine: "January  2026-01-26 Sunday  tags..."
    let header_text = format!("{}  {}{}", month_name, date_str, tag_indicator);

    let header = Paragraph::new(header_text)
        .style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));

    f.render_widget(header, area);
}

fn render_entries(f: &mut Frame, area: Rect, app: &AppState) {
    let entries = app.get_filtered_entries_for_date(&app.current_date);

    if entries.is_empty() {
        let msg = match &app.current_tag_filter {
            crate::models::TagFilter::All => "No entries for this day".to_string(),
            crate::models::TagFilter::Tag(tag) => format!("No #{} entries for this day", tag),
            crate::models::TagFilter::Untagged => "No untagged entries for this day".to_string(),
        };
        
        let no_entries = Paragraph::new(msg)
            .style(Style::default().fg(Color::DarkGray))
            .alignment(Alignment::Center)
            .block(Block::default().borders(Borders::ALL));
        f.render_widget(no_entries, area);
        return;
    }

    // Build text with all entries
    let mut text = Text::default();

    for (idx, entry) in entries.iter().enumerate() {
        if idx > 0 {
            text.lines.push(Line::from("")); // Single blank line separator
        }

        // Time and location line with optional tag
        let mut header_spans = Vec::new();

        // Add tag if present (in cyan brackets)
        if let Some(ref tag) = entry.tag {
            header_spans.push(Span::styled(
                format!("[{}] ", tag),
                Style::default().fg(Color::Cyan),
            ));
        }

        // Add time and location (in yellow bold)
        let time_loc = format!("{} - {}", entry.time.format("%H:%M:%S"), entry.location);
        header_spans.push(Span::styled(
            time_loc,
            Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD),
        ));

        // Get content lines
        let content_lines: Vec<&str> = entry.content.lines().collect();

        if content_lines.is_empty() {
            // Entry has no content, just show header with blank line after
            text.lines.push(Line::from(header_spans));
            text.lines.push(Line::from(""));
        } else {
            // First line: merge with header (two spaces separator)
            let first_line = content_lines[0];
            
            header_spans.push(Span::raw("  "));
            
            // Add first content line to header (with highlighting if active)
            if !app.day_search_query.is_empty() {
                let highlighted = highlight_matches(first_line, &app.day_search_query);
                for span in highlighted.spans {
                    header_spans.push(span);
                }
            } else {
                let parsed = parse_markdown_line(first_line);
                for span in parsed.spans {
                    header_spans.push(span);
                }
            }
            
            text.lines.push(Line::from(header_spans));
            
            // Remaining lines: render normally (no indent)
            for line in content_lines.iter().skip(1) {
                if !app.day_search_query.is_empty() {
                    text.lines.push(highlight_matches(line, &app.day_search_query));
                } else {
                    text.lines.push(parse_markdown_line(line));
                }
            }
        }
    }

    let paragraph = Paragraph::new(text)
        .wrap(Wrap { trim: false })
        .scroll((app.scroll_offset as u16, 0))
        .block(Block::default().borders(Borders::ALL));

    f.render_widget(paragraph, area);
}

fn render_summary_content(f: &mut Frame, area: Rect, app: &AppState) {
    let current_month = app.current_date.month();
    let current_year = app.current_date.year();
    
    // Calculate available width for text (minus borders and day number formatting)
    // area.width - 2 (borders) - 1 (bullet space) - 2 (day DD) - 1 (space) = width - 6
    let content_width = (area.width as usize).saturating_sub(6);
    let indent = "    "; // 4 spaces for wrapped lines
    let indent_width = content_width.saturating_sub(4);
    
    let mut lines = Vec::new();
    
    // Iterate through all days in the month
    for day in 1..=31 {
        if let Some(date) = NaiveDate::from_ymd_opt(current_year, current_month, day) {
            let summary = app.monthly_summaries.get_summary(&date);
            let is_current = date == app.current_date;
            
            if summary.is_empty() {
                // Empty day: just show day number
                let line_text = if is_current {
                    format!(" {:02}", day)
                } else {
                    format!(" {:02}", day)
                };
                
                let style = if is_current {
                    Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(Color::DarkGray)
                };
                
                lines.push(Line::from(vec![Span::styled(line_text, style)]));
            } else {
                // Has summary: wrap to multiple lines if needed
                let words: Vec<&str> = summary.split_whitespace().collect();
                let mut current_line = String::new();
                let mut is_first_line = true;
                
                for word in words {
                    let test_line = if current_line.is_empty() {
                        word.to_string()
                    } else {
                        format!("{} {}", current_line, word)
                    };
                    
                    let available = if is_first_line { content_width } else { indent_width };
                    
                    if test_line.len() <= available {
                        current_line = test_line;
                    } else {
                        // Current line is full, push it and start new line
                        if is_first_line {
                            let line_text = if is_current {
                                format!(" {:02} {}", day, current_line)
                            } else {
                                format!(" {:02} {}", day, current_line)
                            };
                            
                            let style = if is_current {
                                Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
                            } else {
                                Style::default()
                            };
                            
                            lines.push(Line::from(vec![Span::styled(line_text, style)]));
                            is_first_line = false;
                        } else {
                            lines.push(Line::from(format!("{}{}", indent, current_line)));
                        }
                        
                        current_line = word.to_string();
                    }
                }
                
                // Push remaining text
                if !current_line.is_empty() {
                    if is_first_line {
                        let line_text = if is_current {
                            format!(" {:02} {}", day, current_line)
                        } else {
                            format!(" {:02} {}", day, current_line)
                        };
                        
                        let style = if is_current {
                            Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
                        } else {
                            Style::default()
                        };
                        
                        lines.push(Line::from(vec![Span::styled(line_text, style)]));
                    } else {
                        lines.push(Line::from(format!("{}{}", indent, current_line)));
                    }
                }
            }
        } else {
            break; // Month doesn't have this many days
        }
    }
    
    let paragraph = Paragraph::new(lines)
        .block(Block::default().borders(Borders::ALL))
        .scroll((0, 0));
    
    f.render_widget(paragraph, area);
}

fn render_footer(f: &mut Frame, area: Rect, app: &AppState) {
    let help_text = match &app.mode {
        AppMode::DailyView => {
            "j/k:day  h/l:tag  d/u:scroll  i:edit/new I:edit-summary /:day-search Ctrl+s:global c:cal t:today ::jump q:quit"
        }
        _ => "",
    };

    let footer = Paragraph::new(help_text)
        .style(Style::default().fg(Color::Gray))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));

    f.render_widget(footer, area);
}

fn render_day_search_view(f: &mut Frame, app: &AppState) {
    // Create vertical layout
    let vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header row (full width)
            Constraint::Min(0),     // Content row (split horizontally)
            Constraint::Length(3),  // Search input row (full width)
        ])
        .split(f.size());

    // Split content row horizontally (50/50)
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(50),
            Constraint::Percentage(50),
        ])
        .split(vertical_chunks[1]);

    // Header and search input use full width
    let header_area = vertical_chunks[0];
    let search_area = vertical_chunks[2];

    // Render full-width header
    render_combined_header(f, header_area, app);

    // Left side: summary pane
    render_summary_content(f, content_chunks[0], app);

    // Right side: entries with highlights
    render_entries(f, content_chunks[1], app);

    // Full-width search input at bottom
    let search_text = format!("Search day: {}", app.day_search_query);
    let search_input = Paragraph::new(search_text)
        .style(Style::default().fg(Color::Yellow))
        .block(Block::default().borders(Borders::ALL).title("ESC:exit | Enter:keep highlighting"));

    f.render_widget(search_input, search_area);
}

fn render_entry_selection(f: &mut Frame, app: &AppState) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header
            Constraint::Min(0),     // Entry list
            Constraint::Length(3),  // Footer
        ])
        .split(f.size());

    // Header
    let header = Paragraph::new("Select entry to edit or create new")
        .style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(header, chunks[0]);

    // Entry list - add "+ New Entry" as first item
    let entries = app.get_entries_for_date(&app.current_date);
    let mut items: Vec<ListItem> = Vec::new();
    
    // First item: "+ New Entry"
    let new_entry_style = if app.selected_entry_index == 0 {
        Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(Color::Green)
    };
    items.push(ListItem::new("+ New Entry").style(new_entry_style));
    
    // Remaining items: existing entries
    for (idx, entry) in entries.iter().enumerate() {
        let time_loc = format!("{}. {} - {}", 
            idx + 1, 
            entry.time.format("%H:%M:%S"), 
            entry.location
        );
        let preview = entry.content.lines().next().unwrap_or("");
        let content = format!("{}\n    {}", time_loc, preview);
        
        let style = if idx + 1 == app.selected_entry_index {
            Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
        } else {
            Style::default()
        };
        
        items.push(ListItem::new(content).style(style));
    }

    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(list, chunks[1]);

    // Footer
    let footer = Paragraph::new("j/k:navigate Enter:select Esc:cancel")
        .style(Style::default().fg(Color::Gray))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(footer, chunks[2]);
}

fn render_calendar_view(f: &mut Frame, app: &AppState) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),      // Header
            Constraint::Length(12),     // Calendar (fixed height)
            Constraint::Min(5),         // Preview
            Constraint::Length(3),      // Footer
        ])
        .split(f.size());

    // Header
    let month_year = app.calendar_selected_date.format("%B %Y").to_string();
    let header = Paragraph::new(month_year)
        .style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(header, chunks[0]);

    // Calendar
    let calendar_text = crate::calendar::render_calendar(app);
    let calendar = Paragraph::new(calendar_text)
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(calendar, chunks[1]);

    // Preview of selected date's entries
    render_calendar_preview(f, chunks[2], app);

    // Footer
    let footer = Paragraph::new("hjkl:navigate Enter:select Esc:back")
        .style(Style::default().fg(Color::Gray))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(footer, chunks[3]);
}

fn render_calendar_preview(f: &mut Frame, area: Rect, app: &AppState) {
    let entries = app.get_entries_for_date(&app.calendar_selected_date);
    let date_str = app.calendar_selected_date.format("%Y-%m-%d %A").to_string();

    if entries.is_empty() {
        let no_entries = Paragraph::new(format!("{}\n\nNo entries", date_str))
            .style(Style::default().fg(Color::DarkGray))
            .alignment(Alignment::Center)
            .block(Block::default().borders(Borders::ALL).title("Preview"));
        f.render_widget(no_entries, area);
        return;
    }

    // Build preview text with all entries
    let mut text = Text::default();
    text.lines.push(Line::from(vec![
        Span::styled(date_str, Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
    ]));
    text.lines.push(Line::from(""));

    for (idx, entry) in entries.iter().enumerate() {
        if idx > 0 {
            text.lines.push(Line::from(""));
        }

        // Time and location line
        let time_loc = format!("{} - {}", entry.time.format("%H:%M:%S"), entry.location);
        text.lines.push(Line::from(vec![
            Span::styled(time_loc, Style::default().fg(Color::Yellow))
        ]));

        // Content preview (first few lines) with markdown parsing
        let preview_lines: Vec<&str> = entry.content.lines().take(3).collect();
        for line in preview_lines {
            text.lines.push(parse_markdown_line(line));
        }
        
        // Show "..." if there are more lines
        if entry.content.lines().count() > 3 {
            text.lines.push(Line::from(vec![
                Span::styled("...", Style::default().fg(Color::DarkGray))
            ]));
        }
    }

    let paragraph = Paragraph::new(text)
        .wrap(Wrap { trim: false })
        .block(Block::default().borders(Borders::ALL).title("Preview"));

    f.render_widget(paragraph, area);
}

fn render_search_view(f: &mut Frame, app: &AppState) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),  // Search input
            Constraint::Min(0),      // Results
            Constraint::Length(3),  // Footer
        ])
        .split(f.size());

    // Search input
    let search_input = Paragraph::new(format!("Search: {}_", app.search_query))
        .style(Style::default().fg(Color::Cyan))
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(search_input, chunks[0]);

    // Results
    if app.search_results.is_empty() {
        let no_results = Paragraph::new("No results")
            .style(Style::default().fg(Color::DarkGray))
            .alignment(Alignment::Center)
            .block(Block::default().borders(Borders::ALL));
        f.render_widget(no_results, chunks[1]);
    } else {
        let items: Vec<ListItem> = app
            .search_results
            .iter()
            .enumerate()
            .map(|(idx, (date, entry_idx))| {
                let entries = app.get_entries_for_date(date);
                if let Some(entry) = entries.get(*entry_idx) {
                    let preview = entry.content.lines().next().unwrap_or("");
                    let content = format!(
                        "{} {} - {}...",
                        date.format("%Y-%m-%d"),
                        entry.time.format("%H:%M"),
                        preview
                    );
                    
                    let style = if idx == app.selected_entry_index {
                        Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
                    } else {
                        Style::default()
                    };
                    
                    ListItem::new(content).style(style)
                } else {
                    ListItem::new("")
                }
            })
            .collect();

        let list = List::new(items)
            .block(Block::default().borders(Borders::ALL));
        f.render_widget(list, chunks[1]);
    }

    // Footer
    let footer = Paragraph::new("^n/^p:navigate Enter:jump Esc:cancel")
        .style(Style::default().fg(Color::Gray))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(footer, chunks[2]);
}

fn render_jump_to_date(f: &mut Frame, app: &AppState) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),  // Input
            Constraint::Min(0),      // Empty
            Constraint::Length(3),  // Footer
        ])
        .split(f.size());

    // Date input
    let input = Paragraph::new(format!("Jump to date: {}_", app.jump_input))
        .style(Style::default().fg(Color::Cyan))
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(input, chunks[0]);

    // Footer
    let footer = Paragraph::new("Enter:jump Esc:cancel")
        .style(Style::default().fg(Color::Gray))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(footer, chunks[2]);
}
