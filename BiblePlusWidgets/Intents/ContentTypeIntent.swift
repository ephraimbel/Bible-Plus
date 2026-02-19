import AppIntents
import WidgetKit

enum WidgetContentFilter: String, AppEnum {
    case all = "all"
    case versesOnly = "verses"
    case prayersOnly = "prayers"
    case devotionalsOnly = "devotionals"
    case quotesOnly = "quotes"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Content Type")
    static var caseDisplayRepresentations: [WidgetContentFilter: DisplayRepresentation] = [
        .all: "All Content",
        .versesOnly: "Verses Only",
        .prayersOnly: "Prayers Only",
        .devotionalsOnly: "Devotionals Only",
        .quotesOnly: "Quotes Only",
    ]

    var allowedContentTypes: Set<ContentType>? {
        switch self {
        case .all: nil
        case .versesOnly: [.verse]
        case .prayersOnly: [.prayer]
        case .devotionalsOnly: [.devotional]
        case .quotesOnly: [.quote]
        }
    }
}

struct ContentTypeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Content Filter"
    static var description = IntentDescription("Choose what type of content to show")

    @Parameter(title: "Content Type", default: .all)
    var contentType: WidgetContentFilter
}
