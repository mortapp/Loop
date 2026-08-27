import Foundation

/// Centralized date math + formatting. Avoids ad-hoc DateFormatter creation.
nonisolated enum LoopDate {
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    static func startOfDay(_ date: Date = Date()) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Whole calendar days between today and `date` (negative = in the past).
    static func daysRemaining(until date: Date, from reference: Date = Date()) -> Int {
        let components = calendar.dateComponents(
            [.day],
            from: startOfDay(reference),
            to: startOfDay(date)
        )
        return components.day ?? 0
    }

    static func daysElapsed(since date: Date, to reference: Date = Date()) -> Int {
        max(0, daysRemaining(until: reference, from: date))
    }

    // MARK: - Absolute formatting

    /// "Aug 25, 2026"
    static func medium(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    /// "Aug 25"
    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// "Aug 25, 2026 at 4:12 PM"
    static func timestamp(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    /// "Tuesday, August 25"
    static func fullWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    // MARK: - Relative formatting

    /// "Today", "Tomorrow", "Yesterday", "in 4 days", "3 days ago", "Aug 25"
    static func relative(_ date: Date, from reference: Date = Date()) -> String {
        let days = daysRemaining(until: date, from: reference)
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case 2...6: return "in \(days) days"
        case -6 ... -2: return "\(-days) days ago"
        default: return medium(date)
        }
    }

    /// Deadline phrasing: "Due today", "4 days left", "Expired yesterday".
    static func deadline(_ date: Date, from reference: Date = Date()) -> String {
        let days = daysRemaining(until: date, from: reference)
        switch days {
        case 0: return "Due today"
        case 1: return "1 day left"
        case let value where value > 1: return "\(value) days left"
        case -1: return "Expired yesterday"
        default: return "Expired \(-days) days ago"
        }
    }

    /// Ageing phrasing for pending items: "Pending 12 days".
    static func ageDescription(since date: Date, noun: String, from reference: Date = Date()) -> String {
        let days = daysElapsed(since: date, to: reference)
        switch days {
        case 0: return "\(noun) today"
        case 1: return "\(noun) 1 day"
        default: return "\(noun) \(days) days"
        }
    }

    static func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    /// Groups a timeline by month for sectioned lists: "August 2026".
    static func monthKey(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}
