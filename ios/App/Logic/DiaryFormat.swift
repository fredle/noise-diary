import Foundation

/// Text formatting shared by the screens and the PDF.
enum DiaryFormat {
    /// "45 min", "1 h", "2 h 15 min".
    static func duration(minutes: Int) -> String {
        let minutes = max(0, minutes)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        if rest == 0 { return "\(hours) h" }
        return "\(hours) h \(rest) min"
    }

    /// "0:42" for a running clock.
    static func clock(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// "1 min 20 s" or "35 s" for a recording length.
    static func clipLength(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total) s" }
        let rest = total % 60
        return rest == 0 ? "\(total / 60) min" : "\(total / 60) min \(rest) s"
    }

    /// Relative level as a whole number out of 100.
    static func level(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }

    static func entryCount(_ count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }

    static func dayHeader(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func dateAndTime(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute())
    }
}

/// Steps for the duration control: fine-grained for short noise, coarser for long.
enum DurationStep {
    static let maximumMinutes = 24 * 60

    static func increment(_ minutes: Int) -> Int {
        let step: Int
        switch minutes {
        case ..<10: step = 1
        case ..<60: step = 5
        case ..<180: step = 15
        default: step = 30
        }
        return min(maximumMinutes, roundedDown(minutes, to: step) + step)
    }

    static func decrement(_ minutes: Int) -> Int {
        let step: Int
        switch minutes {
        case ...10: step = 1
        case ...60: step = 5
        case ...180: step = 15
        default: step = 30
        }
        let rounded = roundedDown(minutes, to: step)
        return max(1, rounded == minutes ? minutes - step : rounded)
    }

    private static func roundedDown(_ value: Int, to step: Int) -> Int {
        (value / step) * step
    }
}

/// Converts the microphone's dBFS reading into a 0...1 relative level.
/// This is not a calibrated sound pressure level and is never shown as decibels.
enum AudioLevel {
    static let floorDecibels: Float = -60

    static func normalized(decibels: Float) -> Double {
        guard decibels.isFinite else { return 0 }
        let clamped = min(max(decibels, floorDecibels), 0)
        return Double((clamped - floorDecibels) / -floorDecibels)
    }

    static func description(_ value: Double) -> String {
        switch value {
        case ..<0.25: return "Quiet"
        case ..<0.5: return "Moderate"
        case ..<0.75: return "Loud"
        default: return "Very loud"
        }
    }
}
