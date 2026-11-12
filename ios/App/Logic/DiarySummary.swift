import Foundation

/// Totals over a set of records: by day, by time of day and by type of noise.
struct DiarySummary {
    struct DayTotal: Identifiable {
        let day: Date
        let count: Int
        let minutes: Int
        var id: Date { day }
    }

    struct CategoryTotal: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let count: Int
        let minutes: Int
    }

    let entryCount: Int
    let totalMinutes: Int
    let daysWithNoise: Int
    let nightCount: Int
    let recordingCount: Int
    let byDay: [DayTotal]
    let byTimeOfDay: [CategoryTotal]
    let byType: [CategoryTotal]

    init(records: [NoiseRecord], calendar: Calendar = .current) {
        entryCount = records.count
        totalMinutes = records.reduce(0) { $0 + $1.durationMinutes }
        recordingCount = records.filter(\.hasRecording).count

        let days = Dictionary(grouping: records) { calendar.startOfDay(for: $0.startedAt) }
        daysWithNoise = days.count
        byDay = days
            .map { day, items in
                DayTotal(day: day, count: items.count, minutes: items.reduce(0) { $0 + $1.durationMinutes })
            }
            .sorted { $0.day < $1.day }

        let times = Dictionary(grouping: records) { TimeOfDay(date: $0.startedAt, calendar: calendar) }
        nightCount = times[.night]?.count ?? 0
        byTimeOfDay = TimeOfDay.allCases.map { bucket in
            let items = times[bucket] ?? []
            return CategoryTotal(
                id: bucket.rawValue,
                title: bucket.title,
                systemImage: bucket.systemImage,
                count: items.count,
                minutes: items.reduce(0) { $0 + $1.durationMinutes }
            )
        }

        let types = Dictionary(grouping: records) { $0.noiseType }
        byType = types
            .map { type, items in
                CategoryTotal(
                    id: type.rawValue,
                    title: type.title,
                    systemImage: type.systemImage,
                    count: items.count,
                    minutes: items.reduce(0) { $0 + $1.durationMinutes }
                )
            }
            .sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs.minutes > rhs.minutes : lhs.count > rhs.count
            }
    }

    /// The largest count in a list of totals, for scaling bars. Never zero.
    static func maxCount(_ totals: [CategoryTotal]) -> Int {
        max(1, totals.map(\.count).max() ?? 1)
    }
}

/// Periods offered on the totals screen.
enum SummaryPeriod: String, CaseIterable, Identifiable {
    case week
    case fortnight
    case month
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "7 days"
        case .fortnight: return "14 days"
        case .month: return "30 days"
        case .all: return "All"
        }
    }

    /// The first moment included, or nil for everything.
    func startDate(now: Date, calendar: Calendar = .current) -> Date? {
        let days: Int
        switch self {
        case .week: days = 7
        case .fortnight: days = 14
        case .month: days = 30
        case .all: return nil
        }
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(days - 1), to: today)
    }
}

/// Groups items into days, newest day first, keeping each day's order.
enum DayGrouping {
    struct DayGroup<Item>: Identifiable {
        let day: Date
        let items: [Item]
        var id: Date { day }
    }

    static func groups<Item>(_ items: [Item], date: (Item) -> Date, calendar: Calendar = .current) -> [DayGroup<Item>] {
        var order: [Date] = []
        var buckets: [Date: [Item]] = [:]
        for item in items {
            let day = calendar.startOfDay(for: date(item))
            if buckets[day] == nil {
                order.append(day)
                buckets[day] = []
            }
            buckets[day]?.append(item)
        }
        return order
            .sorted(by: >)
            .map { DayGroup(day: $0, items: buckets[$0] ?? []) }
    }
}

/// The days of one month laid out for a calendar grid.
struct MonthLayout {
    let monthStart: Date
    /// Leading nils pad the first week so day 1 falls under the right weekday.
    let cells: [Date?]
    let weekdaySymbols: [String]

    init(containing date: Date, calendar: Calendar = .current) {
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        monthStart = start
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: start))
        }
        self.cells = cells

        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        weekdaySymbols = Array(symbols[first...]) + Array(symbols[..<first])
    }

    func shifted(by months: Int, calendar: Calendar = .current) -> MonthLayout {
        let date = calendar.date(byAdding: .month, value: months, to: monthStart) ?? monthStart
        return MonthLayout(containing: date, calendar: calendar)
    }
}
