import Foundation

/// What the noise was. The wording follows the questions on council noise diary sheets.
enum NoiseType: String, CaseIterable, Identifiable, Codable {
    case music
    case voices
    case banging
    case footsteps
    case tvRadio
    case party
    case dog
    case diy
    case doors
    case alarm
    case vehicle
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: return "Music"
        case .voices: return "Shouting or loud voices"
        case .banging: return "Banging or thumping"
        case .footsteps: return "Footsteps"
        case .tvRadio: return "TV or radio"
        case .party: return "Party or gathering"
        case .dog: return "Dog barking"
        case .diy: return "DIY or machinery"
        case .doors: return "Doors slamming"
        case .alarm: return "Alarm"
        case .vehicle: return "Vehicle or engine"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .music: return "music.note"
        case .voices: return "person.wave.2"
        case .banging: return "hammer"
        case .footsteps: return "figure.walk"
        case .tvRadio: return "tv"
        case .party: return "person.3"
        case .dog: return "pawprint"
        case .diy: return "wrench.and.screwdriver"
        case .doors: return "door.left.hand.closed"
        case .alarm: return "alarm"
        case .vehicle: return "car"
        case .other: return "ellipsis.circle"
        }
    }
}

/// Where the noise came from.
enum NoiseSource: String, CaseIterable, Identifiable, Codable {
    case nextDoor
    case above
    case below
    case outside
    case street
    case unsure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nextDoor: return "Next door"
        case .above: return "Above me"
        case .below: return "Below me"
        case .outside: return "A neighbour's garden or yard"
        case .street: return "The street or a shared area"
        case .unsure: return "Not sure"
        }
    }
}

/// How the noise affected the person keeping the diary.
enum NoiseEffect: String, CaseIterable, Identifiable, Codable {
    case keptAwake
    case wokeUp
    case children
    case work
    case relax
    case conversation
    case leftRoom
    case distressed
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keptAwake: return "Kept me awake"
        case .wokeUp: return "Woke me up"
        case .children: return "Disturbed my children"
        case .work: return "Couldn't work or study"
        case .relax: return "Couldn't relax"
        case .conversation: return "Couldn't hear TV or conversation"
        case .leftRoom: return "Had to leave the room or home"
        case .distressed: return "Made me anxious or distressed"
        case .health: return "Affected my health"
        }
    }
}

/// Time-of-day buckets. Councils treat 23:00 to 07:00 as night time.
enum TimeOfDay: String, CaseIterable, Identifiable {
    case night
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .night: return "Night (23:00–07:00)"
        case .morning: return "Morning (07:00–12:00)"
        case .afternoon: return "Afternoon (12:00–18:00)"
        case .evening: return "Evening (18:00–23:00)"
        }
    }

    var systemImage: String {
        switch self {
        case .night: return "moon.stars"
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "sunset"
        }
    }

    init(hour: Int) {
        switch hour {
        case 7..<12: self = .morning
        case 12..<18: self = .afternoon
        case 18..<23: self = .evening
        default: self = .night
        }
    }

    init(date: Date, calendar: Calendar = .current) {
        self.init(hour: calendar.component(.hour, from: date))
    }
}
