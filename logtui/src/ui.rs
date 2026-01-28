use crate::models::{AppMode, AppState};
use chrono::{Datelike, NaiveDate};
use crossterm::event::{MouseButton, MouseEvent, MouseEventKind};
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
        // Use stronger visual distinctions between header levels: prefixes and
        // different modifier combinations (underline, italic, dim) so levels are
        // more clearly differentiated in the terminal.
        // Render a small pill for the header level (e.g. "#", "##") followed by
        // the header text. Each level uses a distinct pill background color for
        // quick visual scanning while keeping the header text readable.
        let pill_text = format!(" {} ", "#".repeat(hash_count));

        let (bg, fg) = match hash_count {
            1 => (Color::Yellow, Color::Black),
            2 => (Color::Cyan, Color::Black),
            3 => (Color::Magenta, Color::Black),
            4 => (Color::Green, Color::Black),
            5 => (Color::White, Color::Black),
            _ => (Color::DarkGray, Color::White),
        };

        let pill_span = Span::styled(
            pill_text,
            Style::default().bg(bg).fg(fg).add_modifier(Modifier::BOLD),
        );

        // Header text styled strongly so it stands out next to the pill
        let header_span = Span::styled(
            format!(" {}", header_text),
            Style::default()
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        );

        return Line::from(vec![pill_span, header_span]);
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

/// Parse multiple markdown lines and handle fenced code blocks (```)
/// Returns a Vec<Line> where code-block lines are rendered with a distinct style.
fn parse_markdown_lines(lines: &[&str]) -> Vec<Line<'static>> {
    let mut out: Vec<Line<'static>> = Vec::new();
    let mut in_code = false;
    // optional language after opening fence (ignored for now)
    for raw in lines.iter() {
        let s = *raw;
        let trimmed = s.trim_start();
        if trimmed.starts_with("```") {
            // toggle fenced code block state
            in_code = !in_code;
            continue; // do not render the fence itself
        }

        if in_code {
            // Render code line with an indented, dimmed green style to set it
            // apart from normal text. We prefix with two spaces for readability.
            let code_span = Span::styled(
                format!("  {}", s),
                Style::default()
                    .fg(Color::Green)
                    .add_modifier(Modifier::DIM),
            );
            out.push(Line::from(vec![code_span]));
        } else {
            out.push(parse_markdown_line(s));
        }
    }

    // If the file ended while still in a code block, we just stop — this is fine.
    out
}

/// Parse multiple markdown lines, collecting links of the form [text](url).
/// Returns (lines, links) where links is a Vec of discovered URLs in
/// occurrence order. Links inside fenced code blocks are ignored.
fn parse_markdown_lines_with_links(lines: &[&str]) -> (Vec<Line<'static>>, Vec<String>) {
    let mut out: Vec<Line<'static>> = Vec::new();
    let mut links: Vec<String> = Vec::new();
    let mut in_code = false;

    for raw in lines.iter() {
        let s = *raw;
        let trimmed = s.trim_start();
        if trimmed.starts_with("```") {
            in_code = !in_code;
            continue;
        }

        if in_code {
            let code_span = Span::styled(
                format!("  {}", s),
                Style::default()
                    .fg(Color::Green)
                    .add_modifier(Modifier::DIM),
            );
            out.push(Line::from(vec![code_span]));
            continue;
        }

        // We'll scan the line for markdown links [text](url). For each segment
        // between links, parse with the existing inline parser so bold/italic
        // and code formatting still apply. Links are rendered as blue underlined
        // text with a numeric index appended (e.g. "label [1]").
        let mut spans_for_line: Vec<Span<'static>> = Vec::new();
        let mut remaining = s;

        while let Some(open_bracket) = remaining.find('[') {
            // Ensure we have closing bracket and an immediate '(' after )
            if let Some(close_bracket) = remaining[open_bracket..].find(']') {
                let close_bracket = open_bracket + close_bracket;
                // must have '(' after ']'
                let after = remaining.get(close_bracket + 1..).unwrap_or("");
                if after.starts_with('(') {
                    if let Some(close_paren_rel) = after.find(')') {
                        let close_paren = close_bracket + 1 + close_paren_rel;

                        // before, label, url, after
                        let before = &remaining[..open_bracket];
                        let label = &remaining[open_bracket + 1..close_bracket];
                        // slice url content between '(' and ')' (exclude paren)
                        let url = &remaining[close_bracket + 2..close_paren];

                        // Parse `before` using inline parser and append spans
                        if !before.is_empty() {
                            let parsed_before = parse_markdown_line(before);
                            for sp in parsed_before.spans {
                                spans_for_line.push(sp);
                            }
                        }

                        // Register link and render label with index
                        let link_index = links.len() + 1; // 1-based for display
                        links.push(url.to_string());
                        spans_for_line.push(Span::styled(
                            format!("{} [{}]", label, link_index),
                            Style::default()
                                .fg(Color::Blue)
                                .add_modifier(Modifier::UNDERLINED),
                        ));

                        // Continue parsing after the closing paren
                        remaining = &remaining[close_paren + 1..];
                        continue;
                    }
                }
            }

            // No well-formed link found; treat next character literally to avoid
            // an infinite loop. Append up to the next '[' char and continue.
            let idx = open_bracket + 1;
            let literal = &remaining[..idx];
            let parsed_literal = parse_markdown_line(literal);
            for sp in parsed_literal.spans {
                spans_for_line.push(sp);
            }
            remaining = &remaining[idx..];
        }

        // Whatever remains after link processing
        if !remaining.is_empty() {
            let parsed_rem = parse_markdown_line(remaining);
            for sp in parsed_rem.spans {
                spans_for_line.push(sp);
            }
        }

        if spans_for_line.is_empty() {
            out.push(Line::from(Span::raw("")));
        } else {
            out.push(Line::from(spans_for_line));
        }
    }

    (out, links)
}

/// Helper: find and record spans with link indices inside a Line for positioning
fn record_link_positions(
    line: &Line<'static>,
    row: u16,
    mut col_offset: u16,
    link_positions: &mut Vec<(usize, u16, u16, u16)>,
    mut next_link_idx: usize,
) -> usize {
    for span in &line.spans {
        let content = span.content.as_ref();
        // Look for patterns like "[label]" where label is followed by space and
        // an index in brackets: "... [N]" produced by our link renderer.
        // We'll scan the span content to find occurrences of "[<number>]".
        let mut i = 0usize;
        while i < content.len() {
            if let Some(open) = content[i..].find('[') {
                let open_idx = i + open;
                if let Some(close_rel) = content[open_idx..].find(']') {
                    let close_idx = open_idx + close_rel;
                    let inside = &content[open_idx + 1..close_idx];
                    if inside.chars().all(|c| c.is_ascii_digit()) {
                        if let Ok(num) = inside.parse::<usize>() {
                            // compute byte index -> column width roughly as char count
                            let start_col = col_offset + content[..open_idx].width() as u16;
                            let end_col = start_col + content[open_idx..=close_idx].width() as u16;
                            // store 0-based link index (num - 1)
                            link_positions.push((num - 1, row, start_col, end_col));
                            next_link_idx = next_link_idx.max(num);
                        }
                    }
                    i = close_idx + 1;
                    continue;
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        // advance column offset by span width
        col_offset += content.width() as u16;
    }
    next_link_idx
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
        AppMode::SelectEntry => render_entry_selection(f, app),
        AppMode::DaySearchView => render_day_search_view(f, app),
        AppMode::ConfirmDelete(_) => {
            // If the confirm flow was initiated from the selection list,
            // render the selection view underneath the modal; otherwise
            // render the single-entry detail view.
            if app.confirm_from_selection {
                render_entry_selection(f, app);
            } else {
                render_entry_detail(f, app);
            }
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
    // Build a three-part header: month (left), date (center), mode marker (right)
    let month_name = app.current_date.format("%B").to_string(); // Full month name
    let date_str = app.current_date.format("%Y-%m-%d %A").to_string();

    // Mode marker: map AppMode to a short label
    let mode_label = match &app.mode {
        crate::models::AppMode::DailyView | crate::models::AppMode::DaySearchView => "Select Date",
        crate::models::AppMode::SelectEntry => "Select Entry",
        crate::models::AppMode::EntryView(_) => "View Entry",
        crate::models::AppMode::ConfirmDelete(_) => "Confirm",
    }
    .to_string();

    // Tag indicator shown after the centered date if any filter is active
    let tag_indicator = match &app.current_tag_filter {
        crate::models::TagFilter::All => String::new(),
        crate::models::TagFilter::Tag(tag) => format!("  [#{}]", tag),
        crate::models::TagFilter::Untagged => "  [untagged]".to_string(),
    };

    // Add horizontal padding inside the bordered header
    let left_pad = 2usize;
    let right_pad = 2usize;

    // Compute inner width inside borders and subtract padding for layout
    let inner_width = area.width.saturating_sub(2) as usize;
    let content_width = inner_width.saturating_sub(left_pad + right_pad);

    // Compute display widths (unicode aware)
    let month_w = month_name.width();
    let date_and_tag = format!("{}{}", date_str, tag_indicator);
    let date_w = date_and_tag.width();
    let mode_w = mode_label.width();
    // when rendering as a pill we add one space padding on each side
    let pill_mode_w = mode_w + 2;

    // Compute spacing to place date centered and mode right-aligned within content_width
    let date_start = if content_width > date_w {
        (content_width - date_w) / 2
    } else {
        0
    };
    let date_end = date_start + date_w;

    let mut left_space = if date_start > month_w {
        date_start - month_w
    } else {
        1
    };
    let mut mode_start = if content_width > pill_mode_w {
        content_width - pill_mode_w
    } else {
        0
    };
    let mut right_space = if mode_start > date_end {
        mode_start - date_end
    } else {
        1
    };

    // If computed spaces exceed available width (overlap), fallback to minimal spacing
    let total_needed = month_w + left_space + date_w + right_space + mode_w;
    if total_needed > content_width {
        left_space = 1;
        right_space = 1;
    }

    // Build spans with explicit spacing and padding so each part can have its own style
    let mut spans: Vec<Span<'static>> = Vec::new();
    // left padding
    spans.push(Span::raw(" ".repeat(left_pad)));
    // month: match the color used for the current day (highlighted day style)
    spans.push(Span::styled(
        month_name,
        Style::default()
            .fg(Color::Yellow)
            .add_modifier(Modifier::BOLD),
    ));
    spans.push(Span::raw(" ".repeat(left_space)));
    // centered date + tag
    spans.push(Span::styled(
        date_and_tag,
        Style::default()
            .fg(Color::White)
            .add_modifier(Modifier::BOLD),
    ));
    spans.push(Span::raw(" ".repeat(right_space)));
    // mode marker: render as a bright green pill (bg green + black text)
    spans.push(Span::styled(
        format!(" {} ", mode_label),
        Style::default()
            .bg(Color::Green)
            .fg(Color::Black)
            .add_modifier(Modifier::BOLD),
    ));
    // right padding
    spans.push(Span::raw(" ".repeat(right_pad)));

    let text = Text::from(Line::from(spans));

    let header = Paragraph::new(text).block(Block::default().borders(Borders::ALL));
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
    let highlight_entries = matches!(app.mode, AppMode::SelectEntry | AppMode::EntryView(_));
    for (idx, entry) in entries.iter().enumerate() {
        // Determine presence of time and tag
        let has_time = entry.time != chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap();
        let has_tag = entry.tag.as_ref().map(|s| !s.is_empty()).unwrap_or(false);

        let first_content = entry.content.lines().next().unwrap_or("").trim();
        // Prefer explicit frontmatter title when available for previews
        let preview_text = entry.title.as_deref().unwrap_or(first_content);

        // Build a one-line preview according to rules: if both time and tag present, show
        // colored "HH:MM:SS [tag]  content"; otherwise show content only. Ensure the
        // preview uses the same styled spans as the detailed view.
        let mut spans_vec: Vec<Span<'static>> = Vec::new();

        // For visual alignment with the selection view (which reserves a 2-col
        // marker), add a single leading space in the daily list so items line
        // up consistently when switching views.
        spans_vec.push(Span::raw(" "));

        // Determine how to produce the content spans (with or without highlighting)
        let content_line: Line<'static> = if !app.day_search_query.is_empty() {
            highlight_matches(preview_text, &app.day_search_query)
        } else {
            parse_markdown_line(preview_text)
        };

        if has_time && has_tag && !preview_text.is_empty() {
            // Time: highlight only when selection mode is active AND this item is selected
            let time_style = if highlight_entries && idx == app.selected_entry_index {
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(Color::White)
            };

            spans_vec.push(Span::styled(
                format!("{} ", entry.time.format("%H:%M:%S")),
                time_style,
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
            let wrapped = line_len.div_ceil(text_width);
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
        total_wrapped_lines.div_ceil(app.viewport_height)
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
        .scroll((app.scroll_offset, 0))
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

    // Split the area into: date column + summary text. We no longer render a
    // dedicated vertical separator column; the date column includes right
    // padding so the summary text doesn't butt directly against it.
    let date_width = 10;

    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Length(date_width), Constraint::Min(0)])
        .split(area);

    let date_area = chunks[0];
    let summary_area = chunks[1];

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

            // Date column: "DD Dy " (padding will add space on left and right)
            // include an extra trailing space after the DOW so it doesn't run
            // directly into the summary column.
            let date_text = format!("{:02} {} ", day, day_abbr);
            let date_style = if is_current {
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD)
            } else if summary.is_empty() {
                Style::default().fg(Color::DarkGray)
            } else {
                Style::default()
            };
            // Prepend selector glyph for the currently selected date so it matches
            // the entry selection list marker. Reserve two columns for the marker.
            let mut date_spans: Vec<Span<'static>> = Vec::new();
            if is_current {
                date_spans.push(Span::styled("❯ ", Style::default().fg(Color::DarkGray)));
            } else {
                date_spans.push(Span::raw("  "));
            }
            date_spans.push(Span::styled(date_text, date_style));
            date_lines.push(Line::from(date_spans));

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
        AppMode::SelectEntry => {
            "[j/k] navigate  [Enter] open  [n] new  [x] delete  [Esc] cancel"
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

fn render_entry_selection(f: &mut Frame, app: &mut AppState) {
    // Layout: header | content (summary + list) | footer
    let vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header
            Constraint::Min(0),    // Content (split horizontally)
            Constraint::Length(3), // Footer
        ])
        .split(f.size());

    // Header
    render_combined_header(f, vertical_chunks[0], app);

    // Content row: summary (30%) | selection list (70%)
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(30), Constraint::Percentage(70)])
        .split(vertical_chunks[1]);

    // Left: summary pane (keep it visible while selecting an entry)
    render_summary_content(f, content_chunks[0], app);

    // Right: selection list
    let right_area = content_chunks[1];
    let entries = app.get_filtered_entries();
    if entries.is_empty() {
        let no_entries = Paragraph::new("No entries for this day. Press n to create one.")
            .style(Style::default().fg(Color::DarkGray))
            .alignment(Alignment::Center)
            .block(Block::default().borders(Borders::ALL));
        f.render_widget(no_entries, right_area);
    } else {
        // Build list items using the same formatting as the daily entries
        // so the preview (time, tag, markdown parsing) matches exactly.
        let visible_width = right_area.width.saturating_sub(4) as usize; // account for borders/padding
        let mut items: Vec<ListItem> = Vec::new();

        for (idx, entry) in entries.iter().enumerate() {
            let has_time = entry.time != chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap();

            // Build spans for this line following the same rules as render_entries
            let mut spans_vec: Vec<Span<'static>> = Vec::new();

            // Marker: show a gray bullet for the selected item, otherwise two spaces
            // Larger selector glyph for better visibility (black circle)
            let marker = if idx == app.selected_entry_index {
                // Use heavy angle for selection marker (modern, crisp)
                Span::styled("❯ ", Style::default().fg(Color::DarkGray))
            } else {
                Span::raw("  ")
            };
            // reserve marker width (2 columns)
            spans_vec.push(marker);

            // Time and tag formatting
            if has_time {
                // Highlight time only for the currently selected entry to match
                // the date selection pane (selected -> yellow bold).
                let time_style = if idx == app.selected_entry_index {
                    Style::default()
                        .fg(Color::Yellow)
                        .add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(Color::White)
                };

                spans_vec.push(Span::styled(
                    format!("{} ", entry.time.format("%H:%M:%S")),
                    time_style,
                ));

                if let Some(ref tag) = entry.tag {
                    spans_vec.push(Span::styled(
                        format!("[{}] ", tag),
                        Style::default().fg(Color::Cyan),
                    ));
                }
            } else if let Some(ref tag) = entry.tag {
                spans_vec.push(Span::styled(
                    format!("[{}] ", tag),
                    Style::default().fg(Color::Cyan),
                ));
            }

            // Content preview (prefer title frontmatter when present)
            let first_content = entry.content.lines().next().unwrap_or("").trim();
            let preview_text = entry.title.as_deref().unwrap_or(first_content);
            let content_line: Line<'static> = if !app.day_search_query.is_empty() {
                highlight_matches(preview_text, &app.day_search_query)
            } else {
                parse_markdown_line(preview_text)
            };
            for s in content_line.spans {
                spans_vec.push(s);
            }

            // Truncate to fit visible width (subtract marker length already included)
            let line = build_truncated_line(spans_vec, visible_width);
            items.push(ListItem::new(line));
        }

        let list = List::new(items).block(Block::default().borders(Borders::ALL));
        f.render_widget(list, right_area);
    }

    // Footer for selection view
    render_footer(f, vertical_chunks[2], app);
}

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

        // Build a title that mirrors the selection list preview: time, tag,
        // and the explicit `title` frontmatter (or fallback to the first
        // content line). We display that in the block title area and then
        // render the full entry body below it.
        let first_content = entry.content.lines().next().unwrap_or("").trim();
        let has_time = entry.time != chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap();

        let title_display = entry.title.as_deref().unwrap_or(first_content);

        let mut text = Text::default();
        // Render the full body (do not skip the first line; title is separate)
        let mut content_lines: Vec<&str> = entry.content.lines().collect();
        // Trim leading blank lines from the body (users may have left
        // an empty line after the first line when editing).
        if let Some(pos) = content_lines.iter().position(|s| !s.trim().is_empty()) {
            content_lines = content_lines.into_iter().skip(pos).collect();
        } else {
            // All remaining lines are empty -> empty body
            content_lines.clear();
        }
        // Use parse_markdown_lines so fenced code blocks (```...```) are
        // handled across multiple lines instead of parsing each line
        // independently. This ensures code fences toggle correctly and
        // code lines receive the code styling.
        // Use the link-aware parser for the detail view so we can collect
        // clickable links and present numeric link indices to the user.
        let (parsed, links) = parse_markdown_lines_with_links(&content_lines);
        for l in parsed.into_iter() {
            text.lines.push(l);
        }

        // Save discovered links into app state so key handlers can open them.
        app.last_rendered_links.clear();
        for url in links.iter() {
            app.last_rendered_links.push(url.clone());
        }

        // Record approximate on-screen positions for link indices so mouse
        // clicks can be mapped to URLs. We'll compute positions relative to the
        // detail area when the paragraph is rendered below.
        app.last_rendered_link_positions.clear();
        app.last_detail_area = None; // will be set by render below

        // Build a styled title with left padding and colored time/tag to match
        // the selection list formatting.
        let mut title_spans: Vec<Span<'static>> = Vec::new();
        // left padding (1 char)
        title_spans.push(Span::raw(" "));

        if has_time {
            title_spans.push(Span::styled(
                format!("{}", entry.time.format("%H:%M:%S")),
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD),
            ));
            title_spans.push(Span::raw(" "));
            if let Some(ref tag) = entry.tag {
                title_spans.push(Span::styled(
                    format!("[{}] ", tag),
                    Style::default().fg(Color::Cyan),
                ));
            }
        } else if let Some(ref tag) = entry.tag {
            title_spans.push(Span::styled(
                format!("[{}] ", tag),
                Style::default().fg(Color::Cyan),
            ));
        }

        // Title content (from frontmatter or fallback)
        title_spans.push(Span::styled(
            title_display.to_string(),
            Style::default().fg(Color::White),
        ));
        // trailing single space after title content
        title_spans.push(Span::raw(" "));

        // Clone `text` because we need to inspect its lines for link
        // position recording before handing ownership to the Paragraph.
        let text_for_paragraph = text.clone();
        let paragraph = Paragraph::new(text_for_paragraph)
            .wrap(Wrap { trim: false })
            .scroll((app.scroll_offset, 0))
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title(Line::from(title_spans))
                    .padding(ratatui::widgets::Padding::uniform(1)),
            );

        // Before rendering, compute link positions relative to the detail area.
        // We can only approximate horizontal offsets here because ratatui handles
        // wrapping, but we use the built text lines to compute positions.
        // Store area so mouse handlers can map clicks later.
        app.last_detail_area = Some((area.x, area.y, area.width, area.height));

        // For each line we compute the row and call record_link_positions.
        // paragraph.content is private; instead use the `text` we built earlier.
        for (i, line) in text.lines.iter().enumerate() {
            let row = area.y + 1 + i as u16; // 1 for top border/padding
                                             // column offset: start at area.x + 1 (left border/padding)
            let col_offset = area.x + 1;
            let next_idx = 0usize;
            let _ = record_link_positions(
                line,
                row,
                col_offset,
                &mut app.last_rendered_link_positions,
                next_idx,
            );
        }

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
    // Message to show in modal
    let msg = "Delete this entry? Press y to confirm or n/Esc to cancel";

    // Compute desired width based on message length, but clamp to available space
    let max_w = area.width.saturating_sub(4); // leave some margin from terminal edges
                                              // desired inner content width: message width + a little padding
    let msg_w = msg.width();
    let desired_w = (msg_w + 6) as u16; // padding + borders
    let w = desired_w.min(max_w as u16).max(20); // minimum width of 20

    // Available content width inside the modal (subtract borders and padding)
    let content_w = if w > 4 { (w - 4) as usize } else { 1 };

    // Compute how many wrapped lines message will need
    let lines_needed = if content_w > 0 {
        ((msg_w + content_w - 1) / content_w) as u16
    } else {
        1u16
    };

    // Height: title + message lines + padding (clamped)
    let desired_h = lines_needed.saturating_add(3); // title + padding
    let max_h = area.height.saturating_sub(4) as u16;
    let h = desired_h.min(max_h).max(3);

    let x = (area.width.saturating_sub(w)) / 2;
    let y = (area.height.saturating_sub(h)) / 2;
    let rect = Rect::new(x, y, w, h);

    let block = Block::default()
        .borders(Borders::ALL)
        .title("Confirm Delete")
        .style(Style::default().fg(Color::Red));

    let text = Paragraph::new(msg)
        .style(Style::default().fg(Color::White))
        .alignment(Alignment::Center)
        .wrap(Wrap { trim: true })
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
                    let first_content = entry.content.lines().next().unwrap_or("");
                    let preview_text = entry.title.as_deref().unwrap_or(first_content);
                    let content = format!(
                        "{} {} - {}...",
                        date.format("%Y-%m-%d"),
                        entry.time.format("%H:%M"),
                        preview_text
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
