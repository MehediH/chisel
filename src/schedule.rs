use chrono::{Datelike, Local, NaiveTime, Weekday};

use crate::config::Config;

pub fn is_blocked_now(config: &Config) -> bool {
    let now = Local::now();
    let today = now.weekday();

    let today_str = weekday_to_str(today);
    if !config.schedule.days.contains(&today_str.to_string()) {
        return false;
    }

    if config.schedule.all_day {
        return true;
    }

    let start = config
        .schedule
        .start_time
        .as_deref()
        .and_then(|s| NaiveTime::parse_from_str(s, "%H:%M").ok())
        .unwrap_or_else(|| NaiveTime::from_hms_opt(9, 0, 0).unwrap());

    let end = config
        .schedule
        .end_time
        .as_deref()
        .and_then(|s| NaiveTime::parse_from_str(s, "%H:%M").ok())
        .unwrap_or_else(|| NaiveTime::from_hms_opt(17, 0, 0).unwrap());

    let current_time = now.time();
    current_time >= start && current_time < end
}

pub fn next_session_str(config: &Config) -> String {
    let now = Local::now();
    let today = now.weekday();

    for offset in 1..=7 {
        let candidate = weekday_add(today, offset);
        let candidate_str = weekday_to_str(candidate);
        if config.schedule.days.contains(&candidate_str.to_string()) {
            let date = now.date_naive() + chrono::Duration::days(offset as i64);
            return date.format("%A, %b %d").to_string();
        }
    }

    "No upcoming sessions".to_string()
}

pub fn blocking_ends_at(config: &Config) -> String {
    if config.schedule.all_day {
        "end of day".to_string()
    } else {
        config
            .schedule
            .end_time
            .clone()
            .unwrap_or_else(|| "17:00".to_string())
    }
}

fn weekday_to_str(w: Weekday) -> &'static str {
    match w {
        Weekday::Mon => "mon",
        Weekday::Tue => "tue",
        Weekday::Wed => "wed",
        Weekday::Thu => "thu",
        Weekday::Fri => "fri",
        Weekday::Sat => "sat",
        Weekday::Sun => "sun",
    }
}

fn weekday_add(start: Weekday, days: u32) -> Weekday {
    let num = start.num_days_from_monday();
    let target = (num + days) % 7;
    match target {
        0 => Weekday::Mon,
        1 => Weekday::Tue,
        2 => Weekday::Wed,
        3 => Weekday::Thu,
        4 => Weekday::Fri,
        5 => Weekday::Sat,
        6 => Weekday::Sun,
        _ => unreachable!(),
    }
}
