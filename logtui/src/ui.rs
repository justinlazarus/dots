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
        return Line::from(vec![Span::styled(
            line.to_string(),
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        )]);
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
                spans.push(Span::styled(text, Style::default().fg(Color::Green)));
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

pub fn render(f: &mut Frame, app: &mut AppState) {
    match &app.mode {
        AppMode::DailyView => render_daily_view(f, app),
        AppMode::SelectEntry => render_entry_selection(f, app),
        AppMode::SearchView => render_search_view(f, app),
        AppMode::DaySearchView => render_day_search_view(f, app),
        AppMode::QuickEntry | AppMode::FullEntry | AppMode::EditEntry(_) => {
            // External editor is running, nothing to render
            render_daily_view(f, app)
        }
    }
}

fn render_daily_view(f: &mut Frame, app: &mut AppState) {
    // Create vertical layout: header row | content row | footer row
    let vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header row (full width)
            Constraint::Min(0),    // Content row (will split horizontally)
            Constraint::Length(3), // Footer row (full width)
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

    // Render right column (detail pane) and update viewport height
    render_entries(f, content_chunks[1], app);

    // Render full-width footer (help text)
    render_footer(f, footer_area, app);
}

fn render_combined_header(f: &mut Frame, area: Rect, app: &AppState) {
    // Month name + date
    let month_name = app.current_date.format("%B").to_string(); // Full month name
    let date_str = app.current_date.format("%Y-%m-%d %A").to_string();

    // Show current tag filter
    let tag_indicator = match &app.current_tag_filter {
        crate::models::TagFilter::All => String::new(),
        crate::models::TagFilter::Tag(tag) => format!("  [#{}]", tag),
        crate::models::TagFilter::Untagged => "  [untagged]".to_string(),
    };

    // Combine: "January  2026-01-26 Sunday  tags..."
    let header_text = format!("{}  {}{}", month_name, date_str, tag_indicator);

    let header = Paragraph::new(header_text)
        .style(
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        )
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));

    f.render_widget(header, area);
}

fn render_entries(f: &mut Frame, area: Rect, app: &mut AppState) {
    // Update viewport height for page scrolling (subtract borders and padding)
    app.viewport_height = area.height.saturating_sub(4) as usize; // 2 for borders, 2 for padding

    let entries = app.get_filtered_entries();

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

        // Check if entry has explicit time (not 00:00:00 sentinel)
        let has_time = entry.time != chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap();

        if has_time {
            // Entry has time - show time and location in yellow/bold
            let time_loc = format!("{} - {}", entry.time.format("%H:%M:%S"), entry.location);
            header_spans.push(Span::styled(
                time_loc,
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD),
            ));
        } else {
            // Entry has no time (retrospective) - show just location in regular gray
            header_spans.push(Span::styled(
                entry.location.clone(),
                Style::default().fg(Color::Gray),
            ));
        }

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
                    // Apply gray color to retrospective entries
                    if !has_time {
                        header_spans.push(Span::styled(
                            span.content.to_string(),
                            Style::default().fg(Color::Gray),
                        ));
                    } else {
                        header_spans.push(span);
                    }
                }
            } else {
                let parsed = parse_markdown_line(first_line);
                for span in parsed.spans {
                    // Apply gray color to retrospective entries
                    if !has_time {
                        header_spans.push(Span::styled(
                            span.content.to_string(),
                            Style::default().fg(Color::Gray),
                        ));
                    } else {
                        header_spans.push(span);
                    }
                }
            }

            text.lines.push(Line::from(header_spans));

            // Remaining lines: render with gray color for retrospective entries
            for line in content_lines.iter().skip(1) {
                if !has_time {
                    // Retrospective entry - render in gray
                    text.lines.push(Line::from(Span::styled(
                        line.to_string(),
                        Style::default().fg(Color::Gray),
                    )));
                } else {
                    // Normal entry - render with highlighting/markdown
                    if !app.day_search_query.is_empty() {
                        text.lines
                            .push(highlight_matches(line, &app.day_search_query));
                    } else {
                        text.lines.push(parse_markdown_line(line));
                    }
                }
            }
        }
    }

    // Calculate wrapped line count
    // Available width for text: area.width - 2 (borders) - 2 (padding)
    let text_width = area.width.saturating_sub(4) as usize;
    let mut total_wrapped_lines = 0;

    for line in &text.lines {
        // Calculate how many lines this will wrap to
        let line_text: String = line.spans.iter().map(|s| s.content.as_ref()).collect();
        let line_len = line_text.len();
        if line_len == 0 {
            total_wrapped_lines += 1; // Empty line
        } else {
            let wrapped = (line_len + text_width - 1) / text_width;
            total_wrapped_lines += wrapped.max(1);
        }
    }

    // Calculate page info
    let current_page = if app.viewport_height > 0 {
        ((app.scroll_offset as usize) / app.viewport_height) + 1
    } else {
        1
    };
    let total_pages = if app.viewport_height > 0 && total_wrapped_lines > 0 {
        (total_wrapped_lines + app.viewport_height - 1) / app.viewport_height
    } else {
        1
    };

    let page_indicator = if total_pages > 1 {
        format!("Page {}/{}", current_page, total_pages)
    } else {
        String::new() // No indicator for single page
    };

    let paragraph = Paragraph::new(text)
        .wrap(Wrap { trim: false })
        .scroll((app.scroll_offset as u16, 0))
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title(page_indicator)
                .padding(ratatui::widgets::Padding::uniform(1)),
        );

    f.render_widget(paragraph, area);
}

fn render_summary_content(f: &mut Frame, area: Rect, app: &AppState) {
    let current_month = app.current_date.month();
    let current_year = app.current_date.year();

    // Split the area into: date column + vertical separator (1) + summary text
    // Date column needs: 1 (padding left) + 2 (DD) + 1 (space) + 2 (Dy) + 1 (padding right) = 7 + 2 borders = 9
    let date_width = 9;

    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Length(date_width), // Date column with padding
            Constraint::Length(1),          // Vertical separator
            Constraint::Min(0),             // Summary text
        ])
        .split(area);

    let date_area = chunks[0];
    let separator_area = chunks[1];
    let summary_area = chunks[2];

    // Calculate available width for summary text
    let content_width = (summary_area.width as usize).saturating_sub(2); // minus borders
    let indent = "    "; // 4 spaces for wrapped lines
    let indent_width = if content_width > 4 {
        content_width - 4
    } else {
        content_width
    };

    let mut date_lines = Vec::new();
    let mut summary_lines = Vec::new();

    // Iterate through all days in the month
    for day in 1..=31 {
        if let Some(date) = NaiveDate::from_ymd_opt(current_year, current_month, day) {
            let summary = app.monthly_summaries.get_summary(&date);
            let is_current = date == app.current_date;

            // Get 2-char day abbreviation (Mo, Tu, We, etc.)
            let day_abbr = date
                .format("%a")
                .to_string()
                .chars()
                .take(2)
                .collect::<String>();

            // Date column: "DD Dy" (padding will add space on left and right)
            let date_text = format!("{:02} {}", day, day_abbr);
            let date_style = if is_current {
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD)
            } else if summary.is_empty() {
                Style::default().fg(Color::DarkGray)
            } else {
                Style::default()
            };
            date_lines.push(Line::from(vec![Span::styled(date_text, date_style)]));

            // Summary column - collect all lines for this day first
            let mut day_summary_lines: Vec<Line> = Vec::new();

            if summary.is_empty() {
                // No summary - just one empty line
                day_summary_lines.push(Line::from(""));
            } else {
                // Wrap summary text to available width
                let words: Vec<&str> = summary.split_whitespace().collect();
                let mut current_line = String::new();
                let mut is_first_line = true;

                for word in words {
                    let test_line = if current_line.is_empty() {
                        word.to_string()
                    } else {
                        format!("{} {}", current_line, word)
                    };

                    let available = if is_first_line {
                        content_width
                    } else {
                        indent_width
                    };

                    if test_line.len() <= available {
                        current_line = test_line;
                    } else {
                        // Current line is full, push it and start new line
                        if is_first_line {
                            let style = if is_current {
                                Style::default()
                                    .fg(Color::Yellow)
                                    .add_modifier(Modifier::BOLD)
                            } else {
                                Style::default()
                            };
                            day_summary_lines
                                .push(Line::from(vec![Span::styled(current_line.clone(), style)]));
                            is_first_line = false;
                        } else {
                            day_summary_lines
                                .push(Line::from(format!("{}{}", indent, current_line)));
                        }
                        current_line = word.to_string();
                    }
                }

                // Push remaining text
                if !current_line.is_empty() {
                    if is_first_line {
                        let style = if is_current {
                            Style::default()
                                .fg(Color::Yellow)
                                .add_modifier(Modifier::BOLD)
                        } else {
                            Style::default()
                        };
                        day_summary_lines.push(Line::from(vec![Span::styled(current_line, style)]));
                    } else {
                        day_summary_lines.push(Line::from(format!("{}{}", indent, current_line)));
                    }
                }
            }

            // Now add all lines to summary_lines
            // For the first line, we already have a date line
            // For additional lines, add empty date lines
            for (idx, line) in day_summary_lines.iter().enumerate() {
                summary_lines.push(line.clone());
                if idx > 0 {
                    // Add empty date line for wrapped lines
                    date_lines.push(Line::from(""));
                }
            }

            // Add blank line after Sunday for visual week grouping (except last day)
            let is_last_day = day == 31
                || NaiveDate::from_ymd_opt(current_year, current_month, day + 1).is_none();
            if date.weekday() == chrono::Weekday::Sun && !is_last_day {
                date_lines.push(Line::from(""));
                summary_lines.push(Line::from(""));
            }
        } else {
            break; // Month doesn't have this many days
        }
    }

    // Render date column with padding
    let date_paragraph = Paragraph::new(date_lines)
        .block(
            Block::default()
                .borders(Borders::TOP | Borders::BOTTOM | Borders::LEFT)
                .padding(ratatui::widgets::Padding::horizontal(1)),
        )
        .scroll((0, 0));
    f.render_widget(date_paragraph, date_area);

    // Render vertical separator (using default border color)
    let separator = Block::default().borders(Borders::LEFT | Borders::TOP | Borders::BOTTOM);
    f.render_widget(separator, separator_area);

    // Render summary column with padding
    let summary_paragraph = Paragraph::new(summary_lines)
        .block(
            Block::default()
                .borders(Borders::TOP | Borders::BOTTOM | Borders::RIGHT)
                .padding(ratatui::widgets::Padding::horizontal(1)),
        )
        .scroll((0, 0));
    f.render_widget(summary_paragraph, summary_area);
}

fn render_footer(f: &mut Frame, area: Rect, app: &AppState) {
    let help_text = match &app.mode {
        AppMode::DailyView => {
            "[j/k day] [^n/^p month] [h/l tag] [^d/^u page] [i/I edit] [s/^s search] [t today] [q quit]"
        }
        _ => "",
    };

    let footer = Paragraph::new(help_text)
        .style(Style::default().fg(Color::Gray))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));

    f.render_widget(footer, area);
}

fn render_day_search_view(f: &mut Frame, app: &mut AppState) {
    // Create vertical layout
    let vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header row (full width)
            Constraint::Min(0),    // Content row (split horizontally)
            Constraint::Length(3), // Search input row (full width)
        ])
        .split(f.size());

    // Split content row horizontally (50/50)
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
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
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("ESC:exit | Enter:keep highlighting"),
        );

    f.render_widget(search_input, search_area);
}

fn render_entry_selection(f: &mut Frame, app: &AppState) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header
            Constraint::Min(0),    // Entry list
            Constraint::Length(3), // Footer
        ])
        .split(f.size());

    // Header
    let header = Paragraph::new("Select entry to edit or create new")
        .style(
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        )
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(header, chunks[0]);

    // Entry list - add "+ New Entry" as first item
    let entries = &app.entries;
    let mut items: Vec<ListItem> = Vec::new();

    // First item: "+ New Entry"
    let new_entry_style = if app.selected_entry_index == 0 {
        Style::default()
            .fg(Color::Green)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(Color::Green)
    };
    items.push(ListItem::new("+ New Entry").style(new_entry_style));

    // Remaining items: existing entries
    for (idx, entry) in entries.iter().enumerate() {
        let time_loc = format!(
            "{}. {} - {}",
            idx + 1,
            entry.time.format("%H:%M:%S"),
            entry.location
        );
        let preview = entry.content.lines().next().unwrap_or("");
        let content = format!("{}\n    {}", time_loc, preview);

        let style = if idx + 1 == app.selected_entry_index {
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default()
        };

        items.push(ListItem::new(content).style(style));
    }

    let list = List::new(items).block(Block::default().borders(Borders::ALL));
    f.render_widget(list, chunks[1]);

    // Footer
    let footer = Paragraph::new("j/k:navigate Enter:select Esc:cancel")
        .style(Style::default().fg(Color::Gray))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(footer, chunks[2]);
}

fn render_search_view(f: &mut Frame, app: &AppState) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Search input
            Constraint::Min(0),    // Results
            Constraint::Length(3), // Footer
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
                let entries = app.db.get_entries_for_date(*date).unwrap_or_default();
                if let Some(entry) = entries.get(*entry_idx) {
                    let preview = entry.content.lines().next().unwrap_or("");
                    let content = format!(
                        "{} {} - {}...",
                        date.format("%Y-%m-%d"),
                        entry.time.format("%H:%M"),
                        preview
                    );

                    let style = if idx == app.selected_entry_index {
                        Style::default()
                            .fg(Color::Yellow)
                            .add_modifier(Modifier::BOLD)
                    } else {
                        Style::default()
                    };

                    ListItem::new(content).style(style)
                } else {
                    ListItem::new("")
                }
            })
            .collect();

        let list = List::new(items).block(Block::default().borders(Borders::ALL));
        f.render_widget(list, chunks[1]);
    }

    // Footer
    let footer = Paragraph::new("^n/^p:navigate Enter:jump Esc:cancel")
        .style(Style::default().fg(Color::Gray))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(footer, chunks[2]);
}
