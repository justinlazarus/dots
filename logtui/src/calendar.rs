use crate::models::AppState;
use chrono::{Datelike, NaiveDate};
use ratatui::text::Text;

pub fn render_calendar(app: &AppState) -> Text<'static> {
    let selected = app.calendar_selected_date;
    let year = selected.year();
    let month = selected.month();

    // Get first day of month
    let first_day = NaiveDate::from_ymd_opt(year, month, 1).unwrap();
    let first_weekday = first_day.weekday().num_days_from_sunday() as usize;

    // Get number of days in month
    let days_in_month = if month == 12 {
        NaiveDate::from_ymd_opt(year + 1, 1, 1).unwrap()
    } else {
        NaiveDate::from_ymd_opt(year, month + 1, 1).unwrap()
    }
    .signed_duration_since(first_day)
    .num_days() as u32;

    let mut lines = Vec::new();

    // Header with day names
    lines.push("    Sun  Mon  Tue  Wed  Thu  Fri  Sat".to_string());
    lines.push("".to_string());

    let mut line = "   ".to_string();
    let mut day = 1;

    // Empty spaces before first day
    for _ in 0..first_weekday {
        line.push_str("     ");
    }

    // Days of month
    for weekday in first_weekday..7 {
        if day > days_in_month {
            break;
        }

        let date = NaiveDate::from_ymd_opt(year, month, day).unwrap();
        let has_entries = app.has_entries_on_date(&date);
        let is_selected = date == selected;

        let day_str = if is_selected {
            if has_entries {
                format!("[{:2}•]", day)
            } else {
                format!("[{:2}]", day)
            }
        } else {
            if has_entries {
                format!(" {:2}• ", day)
            } else {
                format!(" {:2}  ", day)
            }
        };

        line.push_str(&day_str);
        day += 1;

        if weekday < 6 {
            line.push(' ');
        }
    }

    lines.push(line);

    // Remaining weeks
    while day <= days_in_month {
        let mut line = "   ".to_string();

        for weekday in 0..7 {
            if day > days_in_month {
                line.push_str("     ");
            } else {
                let date = NaiveDate::from_ymd_opt(year, month, day).unwrap();
                let has_entries = app.has_entries_on_date(&date);
                let is_selected = date == selected;

                let day_str = if is_selected {
                    if has_entries {
                        format!("[{:2}•]", day)
                    } else {
                        format!("[{:2}]", day)
                    }
                } else {
                    if has_entries {
                        format!(" {:2}• ", day)
                    } else {
                        format!(" {:2}  ", day)
                    }
                };

                line.push_str(&day_str);
                day += 1;
            }

            if weekday < 6 {
                line.push(' ');
            }
        }

        lines.push(line);
    }

    lines.push("".to_string());
    lines.push(" • = has entries    [...] = selected".to_string());

    Text::raw(lines.join("\n"))
}

pub fn navigate_calendar(
    current: NaiveDate,
    direction: CalendarDirection,
    year: i32,
) -> NaiveDate {
    match direction {
        CalendarDirection::Left => current.pred_opt().unwrap_or(current),
        CalendarDirection::Right => current.succ_opt().unwrap_or(current),
        CalendarDirection::Up => {
            // Go back 7 days
            current.checked_sub_signed(chrono::Duration::days(7))
                .unwrap_or(current)
        }
        CalendarDirection::Down => {
            // Go forward 7 days
            current.checked_add_signed(chrono::Duration::days(7))
                .unwrap_or(current)
        }
    }
    .clamp_to_year(year)
}

pub enum CalendarDirection {
    Left,
    Right,
    Up,
    Down,
}

trait ClampToYear {
    fn clamp_to_year(self, year: i32) -> Self;
}

impl ClampToYear for NaiveDate {
    fn clamp_to_year(self, year: i32) -> Self {
        if self.year() != year {
            // If we went outside the year, clamp to year boundaries
            if self.year() < year {
                NaiveDate::from_ymd_opt(year, 1, 1).unwrap()
            } else {
                NaiveDate::from_ymd_opt(year, 12, 31).unwrap()
            }
        } else {
            self
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_clamp_to_year() {
        let date = NaiveDate::from_ymd_opt(2027, 1, 1).unwrap();
        let clamped = date.clamp_to_year(2026);
        assert_eq!(clamped, NaiveDate::from_ymd_opt(2026, 12, 31).unwrap());

        let date = NaiveDate::from_ymd_opt(2025, 12, 31).unwrap();
        let clamped = date.clamp_to_year(2026);
        assert_eq!(clamped, NaiveDate::from_ymd_opt(2026, 1, 1).unwrap());

        let date = NaiveDate::from_ymd_opt(2026, 6, 15).unwrap();
        let clamped = date.clamp_to_year(2026);
        assert_eq!(clamped, date);
    }
}
