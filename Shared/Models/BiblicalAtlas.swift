import Foundation

// MARK: - Biblical Atlas
//
// A curated table of the places that matter most in scripture, with real
// approximate coordinates, plus a few well-known journeys. Powers the AI's
// [MAP] card so it can show WHERE something happened. Kept as in-code data
// (no bundle/loading) and resolved case-insensitively with common aliases.

struct BiblicalPlace: Equatable {
    let name: String
    let lat: Double
    let lon: Double
}

struct BiblicalJourney {
    let name: String
    let stops: [BiblicalPlace]
}

enum BiblicalAtlas {

    static func place(_ query: String) -> BiblicalPlace? {
        let key = normalize(query)
        return index[key]
    }

    static func journey(_ query: String) -> BiblicalJourney? {
        journeys[normalize(query)]
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "mount ", with: "")
            .replacingOccurrences(of: "mt. ", with: "")
            .replacingOccurrences(of: "mt ", with: "")
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: "sea of ", with: "")
            .replacingOccurrences(of: " river", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: Places

    private static let places: [BiblicalPlace] = [
        .init(name: "Jerusalem", lat: 31.7683, lon: 35.2137),
        .init(name: "Bethlehem", lat: 31.7054, lon: 35.2024),
        .init(name: "Nazareth", lat: 32.7019, lon: 35.2978),
        .init(name: "Sea of Galilee", lat: 32.8000, lon: 35.5900),
        .init(name: "Capernaum", lat: 32.8808, lon: 35.5753),
        .init(name: "Jericho", lat: 31.8667, lon: 35.4500),
        .init(name: "Bethany", lat: 31.7717, lon: 35.2600),
        .init(name: "Samaria", lat: 32.2800, lon: 35.1900),
        .init(name: "Jordan River", lat: 31.8370, lon: 35.5500),
        .init(name: "Mount Sinai", lat: 28.5392, lon: 33.9749),
        .init(name: "Egypt", lat: 30.0444, lon: 31.2357),
        .init(name: "Babylon", lat: 32.5364, lon: 44.4275),
        .init(name: "Damascus", lat: 33.5138, lon: 36.2765),
        .init(name: "Antioch", lat: 36.2021, lon: 36.1604),
        .init(name: "Ephesus", lat: 37.9417, lon: 27.3417),
        .init(name: "Corinth", lat: 37.9060, lon: 22.8790),
        .init(name: "Athens", lat: 37.9838, lon: 23.7275),
        .init(name: "Rome", lat: 41.9028, lon: 12.4964),
        .init(name: "Philippi", lat: 41.0130, lon: 24.2864),
        .init(name: "Thessalonica", lat: 40.6401, lon: 22.9444),
        .init(name: "Colossae", lat: 37.7900, lon: 29.2600),
        .init(name: "Patmos", lat: 37.3089, lon: 26.5475),
        .init(name: "Caesarea", lat: 32.5000, lon: 34.8900),
        .init(name: "Joppa", lat: 32.0540, lon: 34.7520),
        .init(name: "Tyre", lat: 33.2705, lon: 35.2038),
        .init(name: "Sidon", lat: 33.5630, lon: 35.3690),
        .init(name: "Nineveh", lat: 36.3600, lon: 43.1500),
        .init(name: "Ur", lat: 30.9626, lon: 46.1030),
        .init(name: "Mount of Olives", lat: 31.7784, lon: 35.2453),
        .init(name: "Gethsemane", lat: 31.7795, lon: 35.2396),
        .init(name: "Golgotha", lat: 31.7784, lon: 35.2295),
        .init(name: "Emmaus", lat: 31.8400, lon: 35.0200),
        .init(name: "Cana", lat: 32.7470, lon: 35.3390),
        .init(name: "Bethsaida", lat: 32.9100, lon: 35.6300),
        .init(name: "Mount Carmel", lat: 32.7300, lon: 35.0500),
        .init(name: "Mount Tabor", lat: 32.6870, lon: 35.3900),
        .init(name: "Hebron", lat: 31.5326, lon: 35.0998),
        .init(name: "Shechem", lat: 32.2130, lon: 35.2790),
        .init(name: "Bethel", lat: 31.9300, lon: 35.2200),
        .init(name: "Dead Sea", lat: 31.5000, lon: 35.5000),
        .init(name: "Mount Ararat", lat: 39.7019, lon: 44.2983),
        .init(name: "Mount Nebo", lat: 31.7683, lon: 35.7256),
        .init(name: "Gaza", lat: 31.5000, lon: 34.4700),
        .init(name: "Cyprus", lat: 34.7540, lon: 32.4220),
    ]

    private static let aliases: [String: String] = [
        "galilee": "sea of galilee",
        "sinai": "mount sinai",
        "horeb": "mount sinai",
        "olives": "mount of olives",
        "calvary": "golgotha",
        "jordan": "jordan river",
        "jaffa": "joppa",
        "ararat": "mount ararat",
        "nebo": "mount nebo",
        "carmel": "mount carmel",
        "tabor": "mount tabor",
        "tarsus": "antioch",
        "paphos": "cyprus",
        "salt sea": "dead sea",
    ]

    private static let index: [String: BiblicalPlace] = {
        var map: [String: BiblicalPlace] = [:]
        for place in places {
            map[normalize(place.name)] = place
        }
        for (alias, target) in aliases {
            if let place = map[normalize(target)] {
                map[normalize(alias)] = place
            }
        }
        return map
    }()

    // MARK: Journeys

    private static let journeys: [String: BiblicalJourney] = {
        let exodus = BiblicalJourney(name: "The Exodus", stops: [
            .init(name: "Goshen, Egypt", lat: 30.8000, lon: 31.8000),
            .init(name: "Red Sea", lat: 29.9000, lon: 32.5000),
            .init(name: "Mount Sinai", lat: 28.5392, lon: 33.9749),
            .init(name: "Kadesh Barnea", lat: 30.6500, lon: 34.4900),
            .init(name: "Mount Nebo", lat: 31.7683, lon: 35.7256),
            .init(name: "Jericho", lat: 31.8667, lon: 35.4500),
        ])
        let paulFirst = BiblicalJourney(name: "Paul's First Journey", stops: [
            .init(name: "Antioch", lat: 36.2021, lon: 36.1604),
            .init(name: "Cyprus", lat: 34.7540, lon: 32.4220),
            .init(name: "Perga", lat: 36.9610, lon: 30.8540),
            .init(name: "Pisidian Antioch", lat: 38.3060, lon: 31.1890),
            .init(name: "Iconium", lat: 37.8746, lon: 32.4932),
            .init(name: "Lystra", lat: 37.5800, lon: 32.4500),
            .init(name: "Derbe", lat: 37.3500, lon: 33.2700),
        ])
        return [
            "exodus": exodus,
            "paul-first": paulFirst,
            "paul-1": paulFirst,
            "pauls-first-journey": paulFirst,
        ]
    }()
}
