use crate::models::{AppMode, AppState};
use chrono::{Datelike, NaiveDate};
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, List, ListItem, Paragraph, Wrap},
    Frame,
};
use unicode_width::{UnicodeWidthChar, UnicodeWidthStr};

/// Parse a markdown line and return styled spans
fn parse_markdown_line(line: &str) -> Line<'static> {
    let mut spans = Vec::new();
    let chars: Vec<char> = line.chars().collect();
    let mut i = 0;

    // Check for markdown header levels (# through ######) using the collected
    // `chars: Vec<char>` above. If the line starts with one or more '#' followed
    // by a space, treat it as a header and style according to level.
    let mut hash_count = 0usize;
    while hash_count < chars.len() && chars[hash_count] == '#' {
        hash_count += 1;
    }
    if hash_count > 0 && hash_count < chars.len() && chars[hash_count] == ' ' {
        // Build header text from remaining chars after '#+' and the space
        let header_text: String = chars[hash_count + 1..]
            .iter()
            .collect::<String>()
            .trim()
            .to_string();
        let style = match hash_count {
            1 => Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
            2 => Style::default()
                .fg(Color::Blue)
                .add_modifier(Modifier::BOLD),
            3 => Style::default()
                .fg(Color::Magenta)
                .add_modifier(Modifier::BOLD),
            4 => Style::default()
                .fg(Color::Green)
                .add_modifier(Modifier::BOLD),
            5 => Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD),
            _ => Style::default()
                .fg(Color::Gray)
                .add_modifier(Modifier::BOLD),
        };
        return Line::from(vec![Span::styled(header_text, style)]);
    }

    // Check for ordered list with optional indentation, e.g. "1. " or "  2. "
    // and render the numeric marker in gray followed by the parsed remainder.
    let mut pos = 0usize;
    while pos < chars.len() && chars[pos] == ' ' {
        pos += 1;
    }
    let indent_level = pos / 2;
    if pos < chars.len() && chars[pos].is_ascii_digit() {
        let mut j = pos;
        while j < chars.len() && chars[j].is_ascii_digit() {
            j += 1;
        }
        if j < chars.len() && chars[j] == '.' && j + 1 < chars.len() && chars[j + 1] == ' ' {
            let number: String = chars[pos..j].iter().collect();
            let remainder: String = chars[j + 2..].iter().collect();
            let mut spans: Vec<Span<'static>> = Vec::new();
            if indent_level > 0 {
                spans.push(Span::raw("  ".repeat(indent_level)));
            }
            spans.push(Span::styled(
                format!("{}.", number),
                Style::default().fg(Color::Gray),
            ));
            spans.push(Span::raw(" "));
            let rest_line = parse_markdown_line(&remainder);
            for s in rest_line.spans {
                spans.push(s);
            }
            return Line::from(spans);
        }
    }

    // Check for unordered list markers ('- ', '* ', '+ ') at start of line.
    // Render as a light-grey bullet (•) followed by parsed markdown for the rest
    // of the line so inline formatting still applies.
    if chars.len() >= 2
        && (chars[0] == '-' || chars[0] == '*' || chars[0] == '+')
        && chars[1] == ' '
    {
        let remainder: String = chars[2..].iter().collect();
        let mut spans: Vec<Span<'static>> = Vec::new();
        // Bullet (light grey)
        spans.push(Span::styled(
            "• ".to_string(),
            Style::default().fg(Color::Gray),
        ));
        // Parse the remainder as markdown to preserve bold/italic/code and highlights
        let rest_line = parse_markdown_line(&remainder);
        for s in rest_line.spans {
            spans.push(s);
        }
        return Line::from(spans);
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
                        Style::default()
                            .fg(Color::White)
                            .add_modifier(Modifier::BOLD),
                    ));
                    i = end + 2;
                    break;
                }
                end += 1;
            }
            if end + 1 >= chars.len() {
                // No closing **, treat as literal
                spans.push(Span::styled("**".to_string(), Style::default()));
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
                    Style::default()
                        .fg(Color::White)
                        .add_modifier(Modifier::ITALIC),
                ));
                i = end + 1;
            } else {
                spans.push(Span::styled(
                    "*".to_string(),
                    Style::default().fg(Color::White),
                ));
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
                spans.push(Span::styled(
                    "`".to_string(),
                    Style::default().fg(Color::White),
                ));
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
                // make plain text explicit white so it shows up consistently
                spans.push(Span::styled(text, Style::default().fg(Color::White)));
            }
        }
    }

    if spans.is_empty() {
        Line::from(vec![Span::styled(line.to_string(), Style::default())])
    } else {
        Line::from(spans)
    }
}

/// Build a Line from spans truncated to max_width terminal columns. Uses
/// unicode-width to respect fullwidth characters and emojis.
fn build_truncated_line(spans: Vec<Span<'static>>, max_width: usize) -> Line<'static> {
    if max_width == 0 {
        return Line::from("");
    }

    let mut out: Vec<Span<'static>> = Vec::new();
    let mut used: usize = 0;
    let ell = "...";
    let ell_len = ell.width();

    // helper: take as many chars from `s` as fit into `limit` columns
    fn take_by_width(s: &str, limit: usize) -> String {
        let mut acc = 0usize;
        let mut out = String::new();
        for ch in s.chars() {
            let w = ch.width().unwrap_or(0);
            if acc + w > limit {
                break;
            }
            out.push(ch);
            acc += w;
        }
        out
    }

    for span in spans.into_iter() {
        let s = span.content.as_ref();
        let s_width = s.width();

        if used + s_width <= max_width {
            out.push(span);
            used += s_width;
            continue;
        }

        // Need to truncate this span to fit the remaining space (reserving room for ellipsis)
        let remaining = if used + ell_len >= max_width {
            0
        } else {
            max_width - used - ell_len
        };

        if remaining == 0 {
            out.push(Span::styled(ell.to_string(), Style::default()));
            break;
        }

        let truncated = take_by_width(s, remaining);
        let styled = Span::styled(format!("{}{}", truncated, ell), span.style);
        out.push(styled);
        break;
    }

    Line::from(out)
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
            spans.push(Span::styled(
                line[last_end..match_start].to_string(),
                Style::default(),
            ));
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
        spans.push(Span::styled(line[last_end..].to_string(), Style::default()));
    }

    Line::from(spans)
}

pub fn render(f: &mut Frame, app: &mut AppState) {
    match &app.mode {
        AppMode::DailyView => render_daily_view(f, app),
        AppMode::EntryView(_) => render_entry_detail(f, app),
        // SelectEntry and SearchView variants were removed. Only render the
        // modes actively used by the app.
        AppMode::DaySearchView => render_day_search_view(f, app),
        AppMode::ConfirmDelete(_) => {
            render_entry_detail(f, app);
            render_confirm_modal(f, app);
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

    // Split content row horizontally: summary (30%) | detail (70%)
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(30), Constraint::Percentage(70)])
        .split(vertical_chunks[1]);

    // Header and footer areas
    let header_area = vertical_chunks[0];
    let footer_area = vertical_chunks[2];

    // Render header
    render_combined_header(f, header_area, app);

    // Left: summary pane (30%) — renders dates + summaries inside
    render_summary_content(f, content_chunks[0], app);

    // Right: entries list / detail (70%)
    render_entries(f, content_chunks[1], app);

    // Footer
    render_footer(f, footer_area, app);
}

// build_monthly_columns / date/summary column renderers are no longer used by
// the current render flow (we keep the summary renderer used by the main
// views). They can be removed later if you want a smaller binary.
// (monthly column helpers removed) — kept render_summary_content which the
// current UI uses.

// date/summary column helpers removed — render_summary_content remains in use.

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

    // Build a single-line preview for each entry and add to text (one line per entry)
    let mut text = Text::default();
    let visible_width = area.width.saturating_sub(4) as usize; // account for borders/padding
    for entry in entries.iter() {
        // Determine presence of time and tag
        let has_time = entry.time != chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap();
        let has_tag = entry.tag.as_ref().map(|s| !s.is_empty()).unwrap_or(false);

        let first_content = entry.content.lines().next().unwrap_or("").trim();

        // Build a one-line preview according to rules: if both time and tag present, show
        // colored "HH:MM:SS [tag]  content"; otherwise show content only. Ensure the
        // preview uses the same styled spans as the detailed view.
        let mut spans_vec: Vec<Span<'static>> = Vec::new();

        // Determine how to produce the content spans (with or without highlighting)
        let content_line: Line<'static> = if !app.day_search_query.is_empty() {
            highlight_matches(first_content, &app.day_search_query)
        } else {
            parse_markdown_line(first_content)
        };

        if has_time && has_tag && !first_content.is_empty() {
            // Time (yellow bold)
            spans_vec.push(Span::styled(
                format!("{} ", entry.time.format("%H:%M:%S")),
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD),
            ));

            // Tag (cyan)
            spans_vec.push(Span::styled(
                format!("[{}] ", entry.tag.as_ref().unwrap()),
                Style::default().fg(Color::Cyan),
            ));

            // Append content spans
            for s in content_line.spans {
                spans_vec.push(s);
            }
        } else {
            // Content only (possibly highlighted)
            for s in content_line.spans {
                spans_vec.push(s);
            }
        }

        text.lines
            .push(build_truncated_line(spans_vec, visible_width));
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
                // keep horizontal padding but remove vertical padding so the
                // first entry appears on the first line inside the box
                .padding(ratatui::widgets::Padding::horizontal(1)),
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
            "[j/k] day  [^n/^p] month  [h/l] tag  [^d/^u] page  [Enter] open  [s/^s] search  [t] today  [i] add summary  [q] quit"
        }
        AppMode::EntryView(_) => {
            "[j/k] next/prev  [Enter] edit  [n] new  [x] delete  [Esc] back"
        }
        AppMode::ConfirmDelete(_) => {
            "[y/Enter] confirm  [n/Esc] cancel"
        }
        // SelectEntry/SearchView removed; provide only active variants.
        AppMode::DaySearchView => "Type to filter days  Enter:keep  Esc:cancel",
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

// Entry selection view removed.

fn render_entry_detail(f: &mut Frame, app: &mut AppState) {
    // Layout: header | content | footer
    let vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(0),
            Constraint::Length(3),
        ])
        .split(f.size());

    // Use same 30/70 split as the daily view: summary (30%) | detail (70%)
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(30), Constraint::Percentage(70)])
        .split(vertical_chunks[1]);

    render_combined_header(f, vertical_chunks[0], app);

    // Left: summary (30%)
    render_summary_content(f, content_chunks[0], app);

    // Right: single entry detail (70%)
    let area = content_chunks[1];
    app.viewport_height = area.height.saturating_sub(4) as usize;

    let entries = app.get_filtered_entries();

    if entries.is_empty() {
        let no_entries = Paragraph::new("No entries for this day. Press n to create one.")
            .style(Style::default().fg(Color::DarkGray))
            .alignment(Alignment::Center)
            .block(Block::default().borders(Borders::ALL));
        f.render_widget(no_entries, area);
    } else {
        let idx = app.selected_entry_index.min(entries.len() - 1);
        let entry = &entries[idx];

        // Title indicates entry index
        let title = format!("Entry {}/{}", idx + 1, entries.len());

        let mut text = Text::default();

        // Header: keep time and type (tag) on the top line, then leave two blank
        // lines before rendering the full content. Location is shown after time
        // in dim gray to keep context.
        let mut top_header_spans: Vec<Span<'static>> = Vec::new();
        let has_time = entry.time != chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap();

        if has_time {
            top_header_spans.push(Span::styled(
                format!("{}", entry.time.format("%H:%M:%S")),
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD),
            ));

            if let Some(ref tag) = entry.tag {
                top_header_spans.push(Span::styled(
                    format!(" [{}]", tag),
                    Style::default().fg(Color::Cyan),
                ));
            }
        } else if let Some(ref tag) = entry.tag {
            top_header_spans.push(Span::styled(
                format!("[{}]", tag),
                Style::default().fg(Color::Cyan),
            ));
        } else {
            top_header_spans.push(Span::styled(
                entry.location.clone(),
                Style::default().fg(Color::Gray),
            ));
        }

        // Push the top header line
        text.lines.push(Line::from(top_header_spans));

        // Add two blank separator lines before the content
        text.lines.push(Line::from(""));
        text.lines.push(Line::from(""));

        // Now render the full content, each line parsed as markdown
        let content_lines: Vec<&str> = entry.content.lines().collect();
        for line in content_lines.iter() {
            text.lines.push(parse_markdown_line(line));
        }

        let paragraph = Paragraph::new(text)
            .wrap(Wrap { trim: false })
            .scroll((app.scroll_offset as u16, 0))
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title(title)
                    .padding(ratatui::widgets::Padding::uniform(1)),
            );

        f.render_widget(paragraph, area);
    }

    // Footer for entry view
    let footer = Paragraph::new("Enter:edit  n:new  x:delete  Esc:back")
        .style(Style::default().fg(Color::Gray))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(footer, vertical_chunks[2]);
}

fn render_confirm_modal(f: &mut Frame, _app: &AppState) {
    // Centered small modal
    let area = f.size();
    let w = 50.min(area.width.saturating_sub(4));
    let h = 5u16.min(area.height.saturating_sub(4));
    let x = (area.width.saturating_sub(w)) / 2;
    let y = (area.height.saturating_sub(h)) / 2;
    let rect = Rect::new(x, y, w, h);

    let block = Block::default()
        .borders(Borders::ALL)
        .title("Confirm Delete")
        .style(Style::default().fg(Color::Red));

    let text = Paragraph::new("Delete this entry? Press y to confirm or n/Esc to cancel")
        .style(Style::default().fg(Color::White))
        .alignment(Alignment::Center)
        .block(block);

    f.render_widget(text, rect);
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
