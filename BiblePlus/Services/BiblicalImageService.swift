import UIKit
import SwiftUI

// MARK: - Biblical Image Service

/// Maps image keys to bundled classical art assets.
/// The AI references these keys via the system prompt; the service
/// resolves them to UIImage or falls back to a themed gradient.
///
/// Includes a semantic resolver: if the AI emits an unknown or imperfect key,
/// `resolveKey(for:context:)` finds the closest real artwork using tag overlap
/// against the surrounding caption/verse/summary text. This means a chat
/// response always renders relevant art — never a generic gradient — as long
/// as the catalog has any matching theme.
enum BiblicalImageService {

    // MARK: - Image Key Catalog

    /// All known image keys grouped by category.
    /// Each key SHOULD have a matching image set in Assets.xcassets/BiblicalArt/
    /// — but the catalog intentionally contains entries without bundled binaries.
    /// Those entries expand the AI's image vocabulary so it can reach for
    /// narrative-specific concepts; the resolver substitutes the closest
    /// available artwork until binaries are added. See `resolveKey(for:context:)`.
    static let catalog: [String: [ImageEntry]] = [
        "Creation & Genesis": [
            ImageEntry(
                key: "creation_light",
                title: "The Creation of Light",
                artist: "Gustave Doré",
                tags: ["creation", "genesis", "light", "beginning", "hope", "new", "wonder", "cosmic", "order", "darkness", "morning", "first", "god speaks"]
            ),
            ImageEntry(
                key: "creation_eve",
                title: "The Creation of Eve",
                artist: "Gustave Doré",
                tags: ["creation", "eden", "marriage", "companionship", "relationship", "beginning", "genesis", "adam", "eve", "image of god", "humanity"]
            ),
            ImageEntry(
                key: "fall_eden",
                title: "The Expulsion from the Garden of Eden",
                artist: "Thomas Cole",
                tags: ["fall", "sin", "eden", "expulsion", "shame", "exile", "consequences", "broken", "adam", "eve", "serpent", "loss", "innocence", "grace withheld"]
            ),
            ImageEntry(
                key: "gods_curse",
                title: "The Curse of God upon the Serpent",
                artist: "James Tissot",
                tags: ["fall", "curse", "serpent", "judgment", "eden", "promise", "first gospel", "protoevangelium", "enmity", "seed of the woman", "bruise the head", "consequences", "genesis 3", "adam", "eve", "first promise of christ", "sin", "broken world"]
            ),
            ImageEntry(
                key: "cain_abel",
                title: "Cain and Abel Offer Their Sacrifices",
                artist: "Gustave Doré",
                tags: ["jealousy", "anger", "sibling", "sacrifice", "offering", "sin", "consequences", "worship", "rivalry", "first murder", "rejection"]
            ),
            ImageEntry(
                key: "noah_ark",
                title: "The Dove Returns to Noah",
                artist: "James Tissot",
                tags: ["noah", "ark", "dove", "olive leaf", "flood", "waters receding", "ararat", "rescue", "covenant", "rainbow", "deliverance", "obedience", "remnant", "new beginning", "promise", "hope", "sign of peace"]
            ),
            ImageEntry(
                key: "tower_babel",
                title: "The Tower of Babel",
                artist: "Pieter Bruegel the Elder",
                tags: ["pride", "babel", "tower", "scattering", "languages", "ambition", "rebellion", "human achievement", "judgment", "confusion", "babylon", "self-reliance"]
            ),
            ImageEntry(
                key: "abraham_promise",
                title: "Abraham Counting the Stars",
                artist: "Julius Schnorr von Carolsfeld",
                tags: ["abraham", "promise", "covenant", "stars", "faith", "calling", "wandering", "trust", "patriarch", "descendants", "future", "hope", "waiting"]
            ),
            ImageEntry(
                key: "sacrifice_isaac",
                title: "Sacrifice of Isaac",
                artist: "Caravaggio",
                tags: ["faith", "obedience", "trust", "sacrifice", "abraham", "isaac", "surrender", "testing", "trial", "covenant", "father", "son", "moriah", "promise"]
            ),
            ImageEntry(
                key: "jacob_ladder",
                title: "Jacob's Dream",
                artist: "James Tissot",
                tags: ["jacob", "ladder", "stairway", "dream", "vision", "angels", "ascending", "descending", "heaven", "promise", "presence", "alone", "exile", "running", "encounter", "bethel", "wilderness", "sleeping", "stone pillow", "sky open", "covenant", "i am with you"]
            ),
            ImageEntry(
                key: "jacob_wrestling",
                title: "Jacob Wrestling with the Angel",
                artist: "Eugène Delacroix",
                tags: ["jacob", "wrestling", "angel", "struggle", "blessing", "name", "limp", "perseverance", "night", "fight", "transformation", "israel", "stubborn"]
            ),
            ImageEntry(
                key: "jacob_rachel_well",
                title: "Jacob and Rachel at the Well",
                artist: "James Tissot",
                tags: ["jacob", "rachel", "well", "first meeting", "love", "stranger", "fleeing", "cousin", "shepherdess", "watering flock", "providence", "tender", "kiss", "weeping", "haran", "exile", "finding home", "romance", "long road", "wife", "marriage", "patient love"]
            ),
            ImageEntry(
                key: "joseph_dreams",
                title: "Joseph Sold by His Brothers",
                artist: "Konstantin Flavitsky",
                tags: ["joseph", "betrayal", "brothers", "dreams", "jealousy", "pit", "sold", "slavery", "rejection", "favored son", "coat", "hidden purpose"]
            ),
            ImageEntry(
                key: "joseph_egypt",
                title: "Joseph Recognized by His Brothers",
                artist: "Léon Pierre Urbain Bourgeois",
                tags: ["joseph", "forgiveness", "reconciliation", "egypt", "brothers", "providence", "famine", "tears", "reunion", "grace", "you meant evil", "meant for good"]
            ),
        ],
        "Exodus & Wilderness": [
            ImageEntry(
                key: "burning_bush",
                title: "Moses and the Burning Bush",
                artist: "Eugène Pluchart",
                tags: ["moses", "burning bush", "calling", "holy ground", "presence", "voice", "hesitation", "name", "i am", "wilderness", "shepherd", "fear", "vocation", "encounter"]
            ),
            ImageEntry(
                key: "parting_red_sea",
                title: "The Crossing of the Red Sea",
                artist: "Nicolas Poussin",
                tags: ["red sea", "exodus", "deliverance", "miracle", "moses", "pharaoh", "rescue", "trapped", "impossible", "way out", "egypt", "freedom", "salvation", "wall of water"]
            ),
            ImageEntry(
                key: "manna_wilderness",
                title: "The Gathering of Manna",
                artist: "James Tissot",
                tags: ["manna", "provision", "wilderness", "daily bread", "trust", "complaining", "hunger", "rely", "today", "enough", "miracle", "grumbling", "depend"]
            ),
            ImageEntry(
                key: "ten_commandments",
                title: "Moses and the Ten Commandments",
                artist: "James Tissot",
                tags: ["law", "covenant", "moses", "sinai", "commandments", "obedience", "guidance", "authority", "mountain", "tablets", "exodus", "rules", "holiness"]
            ),
            ImageEntry(
                key: "golden_calf",
                title: "The Adoration of the Golden Calf",
                artist: "Nicolas Poussin",
                tags: ["golden calf", "idolatry", "rebellion", "impatience", "false worship", "aaron", "wandering hearts", "idol", "forgetting", "broken covenant", "anger"]
            ),
            ImageEntry(
                key: "brazen_serpent",
                title: "The Brazen Serpent",
                artist: "James Tissot",
                tags: ["serpent", "moses", "lifted up", "look and live", "healing", "judgment", "mercy", "wilderness", "type of christ", "sin", "rebellion", "snakes"]
            ),
        ],
        "Conquest, Judges & Ruth": [
            ImageEntry(
                key: "jericho_walls",
                title: "The Walls of Jericho Falling Down",
                artist: "Julius Schnorr von Carolsfeld",
                tags: ["jericho", "joshua", "walls", "obedience", "patience", "march", "trumpets", "miracle", "victory", "strange instructions", "absurd", "fall down", "promised land"]
            ),
            ImageEntry(
                key: "gideon_fleece",
                title: "Gideon and the Fleece",
                artist: "Maerten van Heemskerck",
                tags: ["gideon", "fleece", "doubt", "confirmation", "courage", "weakness", "small army", "calling", "fear", "patient with doubt", "judges", "sign"]
            ),
            ImageEntry(
                key: "samson_thousand",
                title: "Samson Slaying the Philistines",
                artist: "Gustave Doré",
                tags: ["samson", "philistines", "strength", "thousand", "jawbone", "judges", "delivered", "raw power", "victory", "weakness made strong", "spirit of the lord", "outnumbered", "alone against many", "deliverer", "fight", "courage"]
            ),
            ImageEntry(
                key: "ruth_boaz",
                title: "Ruth in Boaz's Field",
                artist: "James Tissot",
                tags: ["ruth", "boaz", "gleaning", "redeemer", "loyalty", "naomi", "loss", "kindness", "foreigner", "providence", "harvest", "hidden grace", "widow"]
            ),
        ],
        "Kings & Prophets": [
            ImageEntry(
                key: "david_goliath",
                title: "David and Goliath",
                artist: "Caravaggio",
                tags: ["courage", "giant", "fear", "underdog", "faith", "battle", "victory", "weakness", "david", "goliath", "stone", "shepherd", "trust", "impossible", "champion"]
            ),
            ImageEntry(
                key: "david_repents",
                title: "David Penitent",
                artist: "Pier Francesco Mola",
                tags: ["david", "repentance", "psalm 51", "bathsheba", "guilt", "confession", "broken heart", "mercy", "create in me", "sin", "restoration", "weeping"]
            ),
            ImageEntry(
                key: "davids_three_mighty_men",
                title: "Three of David's Captains",
                artist: "James Tissot",
                tags: ["david", "mighty men", "captains", "warriors", "loyalty", "courage", "valor", "brotherhood", "leadership", "devotion", "sacrifice", "soldiers", "strength", "brave", "three", "kingdom", "israel", "military", "allegiance", "stand together", "elite", "faithfulness"]
            ),
            ImageEntry(
                key: "solomon_temple",
                title: "Solomon Dedicates the Temple",
                artist: "James Tissot",
                tags: ["solomon", "temple", "dedication", "glory", "presence", "prayer", "kingdom", "wisdom", "worship", "filled with cloud", "covenant", "house of god"]
            ),
            ImageEntry(
                key: "solomon_judgment",
                title: "The Judgment of Solomon",
                artist: "Nicolas Poussin",
                tags: ["solomon", "wisdom", "judgment", "two mothers", "discernment", "true love", "kingdom", "justice", "asked for wisdom", "discerning", "court"]
            ),
            ImageEntry(
                key: "samuel_called",
                title: "The Voice of the Lord",
                artist: "James Tissot",
                tags: ["samuel", "voice of god", "calling", "hearing god", "listening", "speak lord", "young", "child", "boy", "night", "temple", "prophet", "awakening", "vocation", "here i am", "whisper", "first encounter", "new believer", "beginning", "anointing", "eli", "discernment", "is this god", "learning to hear"]
            ),
            ImageEntry(
                key: "elijah_ravens",
                title: "Elijah Fed by the Ravens",
                artist: "James Tissot",
                tags: ["elijah", "ravens", "provision", "wilderness", "brook", "cherith", "wilderness", "hidden", "cave", "drought", "famine", "daily bread", "trust", "rely", "god provides", "unexpected", "refuge", "hiding", "alone", "exhausted", "running", "sustained", "miracle", "fed", "depend"]
            ),
            ImageEntry(
                key: "elijah_carmel",
                title: "Elijah on Mount Carmel",
                artist: "Lucas Cranach",
                tags: ["elijah", "carmel", "fire from heaven", "baal", "showdown", "single voice", "courage", "altar", "true god", "prophets", "drought", "answer by fire"]
            ),
            ImageEntry(
                key: "elijah_chariot",
                title: "Elijah Taken Up in a Whirlwind",
                artist: "Giuseppe Angeli",
                tags: ["elijah", "chariot", "whirlwind", "elisha", "ascension", "fire", "succession", "mantle", "departure", "double portion", "going up"]
            ),
            ImageEntry(
                key: "isaiah_seraphim",
                title: "Isaiah's Vision of the Seraphim",
                artist: "Benjamin West",
                tags: ["isaiah", "seraphim", "throne", "holy holy holy", "vision", "calling", "unclean lips", "coal", "send me", "glory", "temple", "smoke", "tremble"]
            ),
            ImageEntry(
                key: "jeremiah_lamenting",
                title: "Jeremiah Lamenting the Destruction of Jerusalem",
                artist: "Rembrandt",
                tags: ["jeremiah", "lament", "weeping prophet", "jerusalem", "destruction", "grief", "ruins", "compassion", "tears", "exile", "burden", "faithful in pain"]
            ),
            ImageEntry(
                key: "ezekiel_bones",
                title: "The Vision of the Valley of Dry Bones",
                artist: "Gustave Doré",
                tags: ["ezekiel", "dry bones", "valley", "resurrection", "breath", "spirit", "revival", "hopeless", "rattle", "stand up", "army", "dead", "renewed", "can these bones live"]
            ),
            ImageEntry(
                key: "daniel_lions",
                title: "Daniel in the Lion's Den",
                artist: "Peter Paul Rubens",
                tags: ["faith", "persecution", "courage", "prayer", "protection", "deliverance", "trust", "danger", "daniel", "lions", "den", "integrity", "stand firm", "babylon", "miracle"]
            ),
            ImageEntry(
                key: "daniel_furnace",
                title: "The Three in the Fiery Furnace",
                artist: "Simeon Solomon",
                tags: ["fiery furnace", "shadrach", "meshach", "abednego", "fire", "fourth man", "courage", "but if not", "pressure", "compromise", "daniel", "babylon", "with us"]
            ),
            ImageEntry(
                key: "jonah_whale",
                title: "Jonah and the Whale",
                artist: "Pieter Lastman",
                tags: ["jonah", "whale", "running", "storm", "swallowed", "second chance", "nineveh", "mercy", "reluctant", "deep", "belly", "darkness", "called back"]
            ),
            ImageEntry(
                key: "esther_king",
                title: "Esther Before Ahasuerus",
                artist: "Artemisia Gentileschi",
                tags: ["esther", "courage", "king", "if i perish", "approaching the throne", "for such a time", "vulnerability", "advocate", "intercession", "queen", "fear", "favor"]
            ),
            ImageEntry(
                key: "mordecai_triumph",
                title: "Mordecai's Triumph",
                artist: "James Tissot",
                tags: ["deliverance", "reversal", "vindication", "providence", "justice", "esther", "mordecai", "honor", "rescue", "hidden hand", "for such a time"]
            ),
        ],
        "Wisdom & Lament": [
            ImageEntry(
                key: "job_suffering",
                title: "Job and His Friends",
                artist: "Ilya Repin",
                tags: ["suffering", "loss", "grief", "friends", "questioning", "patience", "trial", "endurance", "pain", "lament", "why", "doubt", "wrestling", "comforters", "job"]
            ),
        ],
        "Life of Jesus — Nativity & Early": [
            ImageEntry(
                key: "annunciation",
                title: "The Annunciation",
                artist: "Henry Ossawa Tanner",
                tags: ["annunciation", "mary", "gabriel", "angel", "yes", "let it be", "obedience", "calling", "interruption", "favor", "incarnation", "young woman", "hidden glory"]
            ),
            ImageEntry(
                key: "nativity",
                title: "The Nativity",
                artist: "Carl Bloch",
                tags: ["birth", "jesus", "incarnation", "hope", "humility", "christmas", "mary", "joseph", "bethlehem", "manger", "savior", "child", "advent", "beginning"]
            ),
            ImageEntry(
                key: "magi_journey",
                title: "Journey of the Magi",
                artist: "James Tissot",
                tags: ["magi", "wise men", "star", "journey", "epiphany", "seekers", "long road", "gold frankincense myrrh", "gentiles", "worship", "outsiders", "follow"]
            ),
            ImageEntry(
                key: "baptism_jesus",
                title: "The Baptism of Christ",
                artist: "Piero della Francesca",
                tags: ["baptism", "jesus", "john the baptist", "jordan", "dove", "spirit", "beloved son", "well pleased", "ministry begins", "identity", "voice from heaven"]
            ),
            ImageEntry(
                key: "jesus_angels",
                title: "Jesus Ministered to by Angels",
                artist: "James Tissot",
                tags: ["temptation", "wilderness", "comfort", "angels", "ministry", "rest", "help", "weakness", "fasting", "exhaustion", "jesus", "satan", "trial"]
            ),
        ],
        "Life of Jesus — Ministry & Miracles": [
            ImageEntry(
                key: "wedding_cana",
                title: "The Wedding at Cana",
                artist: "Paolo Veronese",
                tags: ["cana", "wedding", "water into wine", "first sign", "joy", "celebration", "abundance", "mary", "do whatever he tells you", "best wine", "feast"]
            ),
            ImageEntry(
                key: "woman_well",
                title: "Christ and the Samaritan Woman",
                artist: "Henryk Siemiradzki",
                tags: ["samaritan woman", "well", "thirst", "living water", "outsider", "shame", "history", "five husbands", "seen", "known", "messiah", "encounter", "evangelist"]
            ),
            ImageEntry(
                key: "sermon_mount",
                title: "Sermon on the Mount",
                artist: "Carl Bloch",
                tags: ["teaching", "beatitudes", "blessing", "kingdom", "discipleship", "instruction", "wisdom", "jesus", "mountain", "crowd", "sermon", "ethics", "happy", "blessed"]
            ),
            ImageEntry(
                key: "beatitudes",
                title: "The Beatitudes",
                artist: "James Tissot",
                tags: ["beatitudes", "blessed are", "poor in spirit", "meek", "merciful", "pure in heart", "peacemakers", "persecuted", "kingdom of heaven", "sermon on the mount", "teaching", "jesus seated", "disciples gathered", "happy are", "upside-down kingdom", "ethics of jesus", "matthew 5", "blessing", "comfort", "hunger and thirst for righteousness"]
            ),
            ImageEntry(
                key: "lords_prayer",
                title: "The Lord's Prayer",
                artist: "James Tissot",
                tags: ["prayer", "lords prayer", "our father", "abba", "teaching", "jesus", "disciples", "intimacy", "daily bread", "forgiveness", "kingdom come", "thy will", "instruction", "hillside", "learning to pray", "devotion", "communion", "petition", "asking", "father", "how to pray"]
            ),
            ImageEntry(
                key: "jesus_calms_storm",
                title: "Jesus Calms the Storm",
                artist: "Rembrandt",
                tags: ["storm", "fear", "miracle", "peace", "anxiety", "chaos", "faith", "trust", "calm", "boat", "disciples", "waves", "wind", "afraid", "lord save us"]
            ),
            ImageEntry(
                key: "walking_water",
                title: "Christ Walking on the Sea",
                artist: "Amédée Varint",
                tags: ["walking on water", "peter", "sinking", "lord save me", "doubt", "step out", "boat", "miracle", "fear", "reach out", "little faith", "wind"]
            ),
            ImageEntry(
                key: "miraculous_catch",
                title: "The Miraculous Draught of Fishes",
                artist: "James Tissot",
                tags: ["calling", "discipleship", "abundance", "peter", "fishing", "miracle", "obedience", "provision", "vocation", "boat", "nets", "follow me"]
            ),
            ImageEntry(
                key: "loaves_fishes",
                title: "The Miracle of the Loaves and Fishes",
                artist: "Giovanni Lanfranco",
                tags: ["feeding", "five thousand", "loaves", "fishes", "bread", "boy", "abundance", "small offering", "multiplied", "satisfied", "leftover", "compassion", "crowd", "twelve baskets", "miracle of provision", "feeding 5000"]
            ),
            ImageEntry(
                key: "transfiguration",
                title: "The Transfiguration",
                artist: "Raphael",
                tags: ["transfiguration", "mountain", "glory", "moses", "elijah", "shining", "voice from cloud", "beloved son", "vision", "peter james john", "veil thin"]
            ),
            ImageEntry(
                key: "lazarus_raised",
                title: "The Raising of Lazarus",
                artist: "Vincent van Gogh",
                tags: ["lazarus", "raised", "tomb", "resurrection", "grief", "jesus wept", "if you had been here", "four days", "come forth", "death", "hope", "delay", "mary martha"]
            ),
            ImageEntry(
                key: "bethany_mary_martha",
                title: "Jesus, Mary Magdalene, and Martha at Bethany",
                artist: "James Tissot",
                tags: ["bethany", "mary", "martha", "mary magdalene", "sitting at his feet", "one thing necessary", "good portion", "hospitality", "listening", "rest", "garden", "friendship", "home", "presence", "teaching", "quiet", "discipleship"]
            ),
            ImageEntry(
                key: "suffer_little_children",
                title: "Suffer the Little Children to Come unto Me",
                artist: "James Tissot",
                tags: ["children", "little children", "kingdom of heaven", "suffer the children", "blessing children", "innocence", "humility", "become like children", "tenderness", "welcome", "receive", "family", "parents", "infants", "kindness", "jesus and children"]
            ),
            ImageEntry(
                key: "good_samaritan",
                title: "The Good Samaritan",
                artist: "Vincent van Gogh",
                tags: ["good samaritan", "neighbor", "mercy", "compassion", "outcast", "wounded", "bandits", "bypassed", "love your neighbor", "parable", "kindness", "stranger"]
            ),
            ImageEntry(
                key: "prodigal_son",
                title: "The Return of the Prodigal Son",
                artist: "James Tissot",
                tags: ["prodigal", "son", "father", "running", "embrace", "forgiveness", "coming home", "wasted", "shame", "welcome", "ring", "robe", "celebration", "lost found"]
            ),
            ImageEntry(
                key: "sower_parable",
                title: "The Sower",
                artist: "Vincent van Gogh",
                tags: ["sower", "seed", "soil", "parable", "word", "rocky ground", "thorns", "good soil", "harvest", "kingdom", "scattering", "growth", "patience"]
            ),
            ImageEntry(
                key: "lost_sheep",
                title: "The Lost Sheep",
                artist: "Alfred Soord",
                tags: ["lost sheep", "shepherd", "ninety-nine", "searching", "carried back", "wanderer", "rescue", "rejoicing", "one", "found", "compassion", "no one too far"]
            ),
        ],
        "Holy Week & Passion": [
            ImageEntry(
                key: "triumphal_entry",
                title: "Entry into Jerusalem",
                artist: "James Tissot",
                tags: ["jerusalem", "palm", "hosanna", "king", "passion", "entry", "celebration", "donkey", "crowd", "messiah", "palm sunday", "passover"]
            ),
            ImageEntry(
                key: "last_supper",
                title: "The Last Supper",
                artist: "Leonardo da Vinci",
                tags: ["last supper", "passover", "bread", "cup", "remembrance", "betrayal", "fellowship", "table", "love one another", "covenant", "communion", "twelve"]
            ),
            ImageEntry(
                key: "grotto_agony",
                title: "The Grotto of the Agony",
                artist: "James Tissot",
                tags: ["gethsemane", "garden", "agony", "grotto", "prayer", "not my will", "cup", "alone", "sweat like blood", "submission", "olive trees", "watch and pray", "anguish", "kneeling", "night", "dark hour"]
            ),
            ImageEntry(
                key: "peter_denial",
                title: "Peter's Denial",
                artist: "Carl Bloch",
                tags: ["peter", "denial", "rooster", "courtyard", "shame", "tears", "weeping", "i do not know him", "broken", "fail", "look from jesus", "regret"]
            ),
            ImageEntry(
                key: "pilate_judgment",
                title: "Christ Before Pilate",
                artist: "Mihály Munkácsy",
                tags: ["pilate", "trial", "ecce homo", "what is truth", "silence", "crowd cries", "wash hands", "innocent", "kingdom not of this world", "judgment hall"]
            ),
            ImageEntry(
                key: "scourging",
                title: "The Scourging on the Front",
                artist: "James Tissot",
                tags: ["scourging", "flogging", "whip", "pillar", "column", "passion", "suffering", "roman soldiers", "by his stripes", "wounds", "beaten", "good friday", "praetorium", "crown of thorns prelude", "silent lamb"]
            ),
            ImageEntry(
                key: "veronica",
                title: "A Holy Woman Wipes the Face of Jesus",
                artist: "James Tissot",
                tags: ["veronica", "via dolorosa", "way of sorrows", "wipe face", "cloth", "veil", "compassion", "kindness", "tender", "carrying cross", "stations of the cross", "passion", "good friday", "crown of thorns", "small mercy", "stranger's kindness"]
            ),
            ImageEntry(
                key: "descent_cross",
                title: "The Descent from the Cross",
                artist: "James Tissot",
                tags: ["descent", "deposition", "taken down", "cross", "passion", "good friday", "sorrow", "grief", "lament", "mary", "mother", "joseph of arimathea", "nicodemus", "burial preparation", "tender", "mourning", "loss", "death", "weeping", "stillness", "after the cross", "holy saturday", "carried", "body of christ", "tears", "compassion", "loved deeply"]
            ),
            ImageEntry(
                key: "raising_cross",
                title: "The Raising of the Cross",
                artist: "James Tissot",
                tags: ["cross", "crucifixion", "sacrifice", "suffering", "passion", "atonement", "death", "calvary", "soldiers", "lifted up", "good friday"]
            ),
            ImageEntry(
                key: "crucifixion",
                title: "The Crucifixion",
                artist: "James Tissot",
                tags: ["cross", "crucifixion", "sacrifice", "atonement", "passion", "death", "good friday", "redemption", "love", "forgiveness", "calvary", "blood", "finished"]
            ),
            ImageEntry(
                key: "strike_lance",
                title: "The Strike of the Lance",
                artist: "James Tissot",
                tags: ["lance", "spear", "side pierced", "blood and water", "crucifixion", "soldier", "longinus", "they shall look on him", "passion", "good friday", "death of christ", "centurion", "calvary", "fulfillment", "not a bone broken", "john 19", "witness", "verified death", "cross"]
            ),
            ImageEntry(
                key: "what_lord_saw_cross",
                title: "What Our Lord Saw from the Cross",
                artist: "James Tissot",
                tags: ["cross", "crucifixion", "view from cross", "calvary", "crowd", "mary", "mother", "mockers", "onlookers", "forgive them", "father forgive", "looking down", "passion", "good friday", "suffering", "bystanders", "witnesses"]
            ),
        ],
        "Resurrection & Acts": [
            ImageEntry(
                key: "empty_tomb",
                title: "The Resurrection",
                artist: "Carl Bloch",
                tags: ["resurrection", "empty tomb", "stone rolled", "easter", "risen", "alive", "victory", "death defeated", "angel", "morning", "first day", "hope"]
            ),
            ImageEntry(
                key: "mary_garden",
                title: "Christ Appearing to Mary Magdalene",
                artist: "Alexander Ivanov",
                tags: ["mary magdalene", "garden", "mary", "rabboni", "do not cling", "tears", "recognized", "called by name", "first witness", "weeping", "easter morning"]
            ),
            ImageEntry(
                key: "road_emmaus",
                title: "The Road to Emmaus",
                artist: "Robert Zünd",
                tags: ["emmaus", "road", "stranger", "burning hearts", "scriptures opened", "broken bread", "recognized", "disappointed", "we had hoped", "walking with us"]
            ),
            ImageEntry(
                key: "doubting_thomas",
                title: "The Incredulity of Saint Thomas",
                artist: "Caravaggio",
                tags: ["thomas", "doubt", "wounds", "my lord and my god", "see and believe", "blessed are those who have not seen", "scars", "questions", "unless i see"]
            ),
            ImageEntry(
                key: "ascension",
                title: "The Ascension of Christ",
                artist: "John Singleton Copley",
                tags: ["ascension", "ascending", "clouds", "great commission", "go therefore", "lifted up", "looking up", "two men in white", "promise of return"]
            ),
            ImageEntry(
                key: "pentecost",
                title: "Pentecost",
                artist: "Jean Restout",
                tags: ["pentecost", "spirit", "tongues of fire", "wind", "upper room", "birth of church", "languages", "boldness", "filled", "promise of father", "outpouring"]
            ),
            ImageEntry(
                key: "stoning_stephen",
                title: "The Stoning of Saint Stephen",
                artist: "Rembrandt",
                tags: ["stephen", "stoning", "first martyr", "vision", "jesus standing", "forgive them", "courage", "saul", "witness", "face like an angel", "persecution"]
            ),
            ImageEntry(
                key: "paul_damascus",
                title: "The Conversion of Saul",
                artist: "Caravaggio",
                tags: ["damascus road", "saul", "paul", "conversion", "blinded", "light", "voice", "why persecute me", "fall", "transformation", "calling", "enemy turned friend"]
            ),
            ImageEntry(
                key: "paul_athens",
                title: "Paul Preaching at Athens",
                artist: "Raphael",
                tags: ["paul", "athens", "areopagus", "unknown god", "philosophers", "in him we live", "engaging culture", "gospel for greeks", "altar", "wisdom", "speech"]
            ),
            ImageEntry(
                key: "paul_shipwreck",
                title: "St Paul Shipwrecked on Malta",
                artist: "Laurent de La Hyre",
                tags: ["paul", "shipwreck", "storm", "malta", "viper", "courage in storm", "sovereignty", "all will be saved", "trust in storm", "providence", "fearless"]
            ),
        ],
        "Revelation & Vision": [
            ImageEntry(
                key: "throne_lamb",
                title: "Adoration of the Lamb",
                artist: "Jan van Eyck",
                tags: ["lamb", "throne", "worship", "elders", "revelation", "every tribe", "worthy is the lamb", "vision", "heaven", "redemption song", "eternal worship"]
            ),
            ImageEntry(
                key: "new_jerusalem",
                title: "The New Jerusalem",
                artist: "Gustave Doré",
                tags: ["new jerusalem", "city", "no more tears", "river of life", "tree of life", "dwelling of god", "hope", "future", "new heaven new earth", "all things new"]
            ),
        ],
    ]

    /// Flat list of all entries.
    static let allEntries: [ImageEntry] = {
        catalog.values.flatMap { $0 }
    }()

    /// Flat list of all image keys for system prompt injection.
    static let allKeys: [String] = {
        allEntries.map(\.key).sorted()
    }()

    // MARK: - Lookup

    /// Returns the bundled UIImage for an exact key, or nil if not present in assets.
    /// This is the raw lookup — for fuzzy resolution use `image(for:context:)`.
    /// Tries the bare name first, then the namespaced path as a defense in
    /// depth in case the asset catalog's `provides-namespace` flag flips back on.
    static func rawImage(for key: String) -> UIImage? {
        if let direct = UIImage(named: "biblical_\(key)") {
            return direct
        }
        return UIImage(named: "BiblicalArt/biblical_\(key)")
    }

    /// Smart lookup: resolves the key (handles hallucinated/imperfect keys
    /// by tag-matching against optional context) and returns the bundled image.
    static func image(for key: String, context: String? = nil) -> UIImage? {
        let resolved = resolveKey(for: key, context: context)
        return rawImage(for: resolved)
    }

    /// Returns true if the asset exists for the exact key.
    static func hasImage(for key: String) -> Bool {
        rawImage(for: key) != nil
    }

    /// Returns the entry metadata for a key (uses smart resolution).
    static func entry(for key: String, context: String? = nil) -> ImageEntry? {
        let resolved = resolveKey(for: key, context: context)
        return allEntries.first { $0.key == resolved }
    }

    // MARK: - Semantic Resolver

    /// Resolves any string the AI might emit (real key, partial key, made-up key,
    /// or even a scene description) into the best-matching catalog key
    /// **whose asset is actually bundled**. This is the contract: callers can trust
    /// that `rawImage(for: resolveKey(...))` returns a real image, never nil
    /// (unless the catalog ships with zero bundled assets).
    ///
    /// Resolution order — every step filters by `hasImage`:
    /// 1. Exact key match against a bundled asset.
    /// 2. Substring match against bundled-asset keys
    ///    (e.g. "calms_storm" → "jesus_calms_storm").
    /// 3. Tag overlap scoring against input + context, **restricted to entries
    ///    with bundled assets**. Catalog entries without binaries still
    ///    participate as a routing signal: their tags lend their themes to the
    ///    asset-bearing entries via the resolver's input substitution.
    /// 4. Final fallback to the first bundled asset.
    ///
    /// Design note: it is INTENTIONAL that the catalog contains entries without
    /// bundled assets. They expand the AI's image vocabulary so it can reach for
    /// narrative-specific concepts ("noah_ark", "pentecost") even before the
    /// binaries land. The resolver then substitutes the closest available
    /// artwork. As binaries are added, they automatically light up.
    static func resolveKey(
        for input: String,
        context: String? = nil,
        excluding: Set<String> = [],
        seed: Int = 0
    ) -> String {
        let normalized = normalize(input)

        // 1. Exact match with bundled asset (skip if recently used in this
        //    conversation — we want variety over the AI's exact pick).
        if !normalized.isEmpty, hasImage(for: normalized), !excluding.contains(normalized) {
            return normalized
        }

        // Pre-compute the set of entries that actually have bundled assets.
        // Every subsequent step works only against this set so we never return
        // a key the renderer can't load.
        let availableEntries = allEntries.filter { hasImage(for: $0.key) }

        // Apply the recent-use exclusion. If it would empty the pool entirely
        // (small catalog or long conversation), fall back to the full set.
        let usableEntries = availableEntries.filter { !excluding.contains($0.key) }
        let candidates = usableEntries.isEmpty ? availableEntries : usableEntries

        // If the input matched a *catalog* entry without a binary, fold its
        // tags into the haystack so its theme still routes to the right art.
        var inputAugmentation = ""
        if !normalized.isEmpty,
           let phantomEntry = allEntries.first(where: { $0.key == normalized }),
           !hasImage(for: phantomEntry.key) {
            inputAugmentation = phantomEntry.tags.joined(separator: " ") + " " + phantomEntry.title
        }

        // 2. Substring match against candidates only
        if !normalized.isEmpty {
            let substring = candidates.first { entry in
                entry.key.contains(normalized) || normalized.contains(entry.key)
            }
            if let substring { return substring.key }
        }

        // 3. Subject-token gating (NEW).
        //
        // Extract specific "who/what is this about" tokens from input + context
        // and the phantom catalog entry. If we find any, restrict scoring to
        // candidates that share at least one subject token. Generic theme
        // overlap alone is not allowed to substitute one biblical figure for
        // another (the bug this guards against: an Elijah story rendering as
        // Daniel-in-the-lions just because they share "courage", "faith",
        // "prayer" tags).
        let phantomEntry = (!normalized.isEmpty)
            ? allEntries.first(where: { $0.key == normalized && !hasImage(for: $0.key) })
            : nil

        var inputSubjects = subjectTokens(from: input)
        if let context { inputSubjects.formUnion(subjectTokens(from: context)) }
        if let phantomEntry {
            inputSubjects.formUnion(subjectTokens(from: phantomEntry.title))
            for tag in phantomEntry.tags {
                inputSubjects.formUnion(subjectTokens(from: tag))
            }
        }

        let subjectFiltered: [ImageEntry]
        let hadSubjectSignal = !inputSubjects.isEmpty
        if hadSubjectSignal {
            subjectFiltered = candidates.filter { entry in
                !candidateSubjectTokens(entry).isDisjoint(with: inputSubjects)
            }
        } else {
            subjectFiltered = candidates
        }

        // 4. Tag-overlap scoring against input + context + phantom-entry tags,
        //    restricted to subject-relevant candidates.
        let haystack = ([input, inputAugmentation, context]
            .compactMap { $0 }
            .filter { !$0.isEmpty })
            .joined(separator: " ")
            .lowercased()

        let scoringPool = subjectFiltered

        if !haystack.isEmpty, !scoringPool.isEmpty {
            let scored = scoringPool
                .map { entry -> (entry: ImageEntry, score: Int) in
                    var score = 0
                    // Subject token overlap dominates — each shared specific
                    // token is worth far more than a generic tag hit.
                    let entrySubjects = candidateSubjectTokens(entry)
                    let sharedSubjects = entrySubjects.intersection(inputSubjects)
                    score += sharedSubjects.count * 10

                    for tag in entry.tags {
                        if haystack.contains(tag.lowercased()) {
                            // Longer tags are slightly more specific
                            score += max(1, tag.count / 4)
                        }
                    }
                    // Title token overlap as a secondary signal
                    for token in entry.title.lowercased().split(separator: " ") where token.count > 3 {
                        if haystack.contains(token) { score += 1 }
                    }
                    return (entry, score)
                }
                .sorted { lhs, rhs in
                    if lhs.score != rhs.score { return lhs.score > rhs.score }
                    return lhs.entry.key < rhs.entry.key
                }

            let positive = scored.filter { $0.score > 0 }
            if !positive.isEmpty {
                // Pick from top thematic matches using the seed for variety.
                let topK = Array(positive.prefix(3))
                let pickIndex = abs(seed) % topK.count
                return topK[pickIndex].entry.key
            }
        }

        // 5. Subject signal but nothing matched → neutral fallback.
        // (This is the key fix: prefer a majestic-but-neutral image over a
        // confidently wrong subject.)
        if hadSubjectSignal, let neutral = neutralFallback(excluding: excluding) {
            return neutral
        }

        // 6. Fallback: rotate through bundled assets by seed.
        if !candidates.isEmpty {
            let pickIndex = abs(seed) % candidates.count
            return candidates[pickIndex].key
        }
        if let firstAsset = availableEntries.first {
            return firstAsset.key
        }
        return allKeys.first ?? input
    }

    // MARK: - Per-Conversation Variety

    /// Per-message resolved-key cache. Keeps SwiftUI re-renders stable so the
    /// same message always shows the same artwork while still letting NEW
    /// messages pick fresh art.
    private static var resolvedKeyCache: [UUID: String] = [:]

    /// Recently-used keys per conversation. The resolver excludes these so
    /// each new scripture card in a conversation surfaces a different artwork.
    private static var recentKeysByConversation: [UUID: [String]] = [:]

    /// How many recent keys to remember per conversation before the oldest
    /// drops out and becomes eligible again.
    private static let recentWindowSize = 6

    /// Message-aware resolver. Use this from chat bubbles so each scripture
    /// card in a conversation rotates through different artworks. Stable
    /// per `messageId` (cache-backed) so SwiftUI re-renders never reshuffle.
    static func resolveKey(
        for input: String,
        context: String?,
        messageId: UUID,
        conversationId: UUID
    ) -> String {
        if let cached = resolvedKeyCache[messageId] {
            return cached
        }

        let recent = Set(recentKeysByConversation[conversationId] ?? [])
        let resolved = resolveKey(
            for: input,
            context: context,
            excluding: recent,
            seed: messageId.hashValue
        )

        resolvedKeyCache[messageId] = resolved

        var list = recentKeysByConversation[conversationId] ?? []
        if !list.contains(resolved) {
            list.append(resolved)
            if list.count > recentWindowSize {
                list.removeFirst(list.count - recentWindowSize)
            }
            recentKeysByConversation[conversationId] = list
        }

        return resolved
    }

    /// Normalizes an AI-emitted key: strips "biblical_" prefix, lowercases,
    /// replaces hyphens/spaces with underscores, removes any remaining junk.
    private static func normalize(_ raw: String) -> String {
        var s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("biblical_") { s.removeFirst("biblical_".count) }
        s = s.replacingOccurrences(of: "-", with: "_")
        s = s.replacingOccurrences(of: " ", with: "_")
        s = s.replacingOccurrences(of: #"[^a-z0-9_]"#, with: "", options: .regularExpression)
        return s
    }

    // MARK: - Default Image (used when nothing else loads)

    /// Returns a guaranteed-loadable bundled artwork. Used as the ultimate
    /// fallback when a requested key has no binary AND the resolver couldn't
    /// substitute a thematic match. Picks deterministically per key so the
    /// same scripture card always shows the same fallback art across renders.
    ///
    /// Walks the small set of bundled "universal" keys — works because these
    /// are guaranteed to exist in the asset catalog (verified at build time).
    static func defaultImage(for key: String) -> UIImage? {
        let universalKeys = [
            "creation_light",      // Creation — works for any beginning/origin
            "sermon_mount",        // Teaching — works for any instruction
            "jesus_calms_storm",   // Peace amid chaos — emotional anchor
            "sacrifice_isaac",     // Faith / surrender
            "nativity",            // Hope / new beginning
            "miraculous_catch",    // Calling / abundance
        ]
        let hash = abs(key.hashValue)
        let pick = universalKeys[hash % universalKeys.count]
        return rawImage(for: pick)
    }

    /// Returns the catalog entry for whichever default image is being shown
    /// for `key`. Lets the bubble's artist credit line stay accurate even when
    /// we're rendering a fallback artwork.
    static func defaultEntry(for key: String) -> ImageEntry? {
        let universalKeys = [
            "creation_light", "sermon_mount", "jesus_calms_storm",
            "sacrifice_isaac", "nativity", "miraculous_catch",
        ]
        let hash = abs(key.hashValue)
        let pick = universalKeys[hash % universalKeys.count]
        return allEntries.first { $0.key == pick }
    }

    // MARK: - Fallback Gradient (legacy — kept for any existing call sites)

    /// Warm-toned wash that matches the chat's design language. Used as a
    /// last-resort when even the default image lookup fails (which should
    /// never happen as long as the bundled set is non-empty). No more
    /// rotating hue chaos — this matches the topGoldGradient elsewhere.
    static func fallbackGradient(for key: String) -> LinearGradient {
        return LinearGradient(
            stops: [
                .init(color: Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.20), location: 0.0),
                .init(color: Color(red: 0.65, green: 0.48, blue: 0.25).opacity(0.10), location: 0.5),
                .init(color: Color(red: 0.20, green: 0.15, blue: 0.08).opacity(0.18), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Formatted Key List for System Prompt

    /// Returns a tag-rich string of all available images for the AI system prompt.
    /// Format per line: `key — short tag list`. Lets the model pick by meaning,
    /// not just by recognizing the key name.
    ///
    /// Tuned for token economy: 4 tags per entry across 60 entries ≈ 3000 chars
    /// total, comfortably within the edge function's per-message length budget.
    /// Vocabulary exposed to the AI in the system prompt.
    /// **Only includes keys that have a bundled asset** — this prevents the AI
    /// from confidently picking a key the resolver then has to fuzzy-substitute
    /// (which historically led to wrong-subject art, e.g. Daniel-in-lions for an
    /// Elijah story). Catalog entries without bundled assets stay in the catalog
    /// for resolver-internal routing but never reach the model.
    static var imageKeyVocabulary: String {
        catalog.compactMap { category, entries in
            let bundled = entries.filter { hasImage(for: $0.key) }
            guard !bundled.isEmpty else { return nil }
            let lines = bundled.map { entry -> String in
                let topTags = entry.tags.prefix(4).joined(separator: ", ")
                return "  • \(entry.key) — \(topTags)"
            }.joined(separator: "\n")
            return "\(category):\n\(lines)"
        }.joined(separator: "\n")
    }

    // MARK: - Subject Token Extraction (resolver hardening)

    /// Stop tokens that should never be treated as a "subject" — they're either
    /// generic English connectors or generic spiritual themes that match almost
    /// every entry's tags and would defeat subject-based filtering.
    private static let subjectStopwords: Set<String> = [
        // English connectors
        "the", "and", "for", "with", "from", "into", "upon", "this", "that",
        "these", "those", "what", "when", "where", "while", "have", "has",
        "had", "will", "would", "could", "should", "their", "them", "they",
        "your", "yours", "mine", "ours", "after", "before", "about", "than",
        "then", "there", "here", "been", "being", "still", "must", "every",
        "many", "some", "such", "very", "even", "more", "most", "much", "also",
        // Generic spiritual themes (match too many candidates to be useful as subject)
        "faith", "love", "hope", "trust", "peace", "grace", "mercy", "joy",
        "fear", "doubt", "anger", "shame", "guilt", "rest", "comfort",
        "courage", "wisdom", "strength", "patience", "prayer", "praying",
        "healing", "salvation", "kingdom", "spirit", "father", "lord",
        "jesus", "christ", "lord's", "god", "gods", "holy", "sin", "soul",
        "heart", "voice", "story", "scripture", "verse", "narrative",
        "moment", "moments", "today", "world", "people", "person", "life"
    ]

    /// Pulls subject-bearing tokens from a free-form string.
    /// Subject tokens are alphabetic words ≥4 chars, lowercased, excluding
    /// the stopword set above. Used to identify *who/what* a passage is
    /// about so the resolver can require subject overlap before substituting
    /// art (preventing wrong-figure substitutions).
    private static func subjectTokens(from text: String) -> Set<String> {
        let lowered = text
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
        var tokens = Set<String>()
        let scalars = lowered.unicodeScalars
        var current = ""
        for scalar in scalars {
            if CharacterSet.lowercaseLetters.contains(scalar) {
                current.append(Character(scalar))
            } else {
                if current.count >= 4, !subjectStopwords.contains(current) {
                    tokens.insert(current)
                }
                current = ""
            }
        }
        if current.count >= 4, !subjectStopwords.contains(current) {
            tokens.insert(current)
        }
        return tokens
    }

    /// Subject tokens for a candidate entry: union of key, title, and tag tokens.
    private static func candidateSubjectTokens(_ entry: ImageEntry) -> Set<String> {
        var tokens = subjectTokens(from: entry.key)
        tokens.formUnion(subjectTokens(from: entry.title))
        for tag in entry.tags {
            tokens.formUnion(subjectTokens(from: tag))
        }
        return tokens
    }

    /// Designated "subject-neutral" bundled keys, in priority order.
    /// Used as a graceful fallback when the input has clear subject tokens
    /// but no bundled candidate shares any of them — far better to show a
    /// majestic, theme-neutral piece of art than to confidently render a
    /// scene depicting a different biblical figure.
    private static let neutralFallbackKeys: [String] = [
        "creation_light",
        "sermon_mount",
        "ten_commandments",
        "creation_eve"
    ]

    private static func neutralFallback(excluding: Set<String>) -> String? {
        for key in neutralFallbackKeys where hasImage(for: key) && !excluding.contains(key) {
            return key
        }
        // If everything is excluded, return the first available neutral.
        return neutralFallbackKeys.first(where: { hasImage(for: $0) })
    }
}

// MARK: - Image Entry

struct ImageEntry: Identifiable {
    let key: String
    let title: String
    let artist: String
    /// Semantic tags for fuzzy resolution. Lowercase, single concepts.
    let tags: [String]

    var id: String { key }
}

// MARK: - Download Checklist

/// Run `BiblicalImageService.printDownloadChecklist()` in debug to get
/// the prioritized list of images to source and add to the asset catalog.
///
/// PRIORITY ORDERING: missing images are grouped into tiers by how often the
/// AI is likely to reach for them and how much visual variety they unlock.
/// Tier 1 = ship these next; Tier 4 = nice to have.
extension BiblicalImageService {

    /// Keys ranked by acquisition priority. Higher tiers should be sourced first.
    /// The ranking reflects: (a) how frequently the AI will route to this theme
    /// in real conversations, and (b) how much variety it adds to the existing
    /// 18-image set.
    static let acquisitionPriority: [(tier: Int, label: String, keys: [String])] = [
        (1, "TIER 1 — ESSENTIAL (massively used themes, biggest visual lift)", [
            "empty_tomb",        // resurrection — central, currently unrepresented
            "last_supper",       // most-referenced communion image
            "prodigal_son",      // most-referenced parable
            "good_samaritan",    // most-referenced parable #2
            "annunciation",      // mary / calling / hidden glory
            "burning_bush",      // calling / vocation / encounter
            "parting_red_sea",   // deliverance / impossible situations
            "gethsemane",        // suffering / submission / agony
            "pentecost",         // spirit / boldness / church
            "lazarus_raised",    // grief / hope / "if you had been here"
        ]),
        (2, "TIER 2 — HIGH IMPACT (broad emotional/teaching coverage)", [
            "jonah_whale",       // running / second chance
            "noah_ark",          // judgment / rescue / covenant
            "joseph_egypt",      // forgiveness / providence
            "ezekiel_bones",     // hopeless situations / revival
            "road_emmaus",       // disappointment / hidden presence
            "walking_water",     // doubt / "save me"
            "elijah_carmel",     // courage / single voice
            "doubting_thomas",   // doubt / wounds / belief
            "feeding_5000",      // small offering / abundance
            "transfiguration",   // glory / vision
        ]),
        (3, "TIER 3 — RICH VARIETY (deepens teaching range)", [
            "jacob_ladder",
            "jacob_wrestling",
            "joseph_dreams",
            "ten_commandments",  // already missing in current 18
            "manna_wilderness",
            "isaiah_seraphim",
            "daniel_furnace",
            "esther_king",
            "ruth_boaz",
            "baptism_jesus",
            "wedding_cana",
            "woman_well",
            "sower_parable",
            "lost_sheep",
            "peter_denial",
            "mary_garden",
            "ascension",
            "paul_damascus",
            "throne_lamb",
            "new_jerusalem",
        ]),
        (4, "TIER 4 — NICE TO HAVE (completes the catalog)", [
            "fall_eden",
            "tower_babel",
            "abraham_promise",
            "golden_calf",
            "brazen_serpent",
            "jericho_walls",
            "gideon_fleece",
            "samson_pillars",
            "david_repents",
            "solomon_temple",
            "solomon_judgment",
            "elijah_chariot",
            "jeremiah_lamenting",
            "magi_journey",
            "pilate_judgment",
            "stoning_stephen",
            "paul_athens",
            "paul_shipwreck",
        ]),
    ]

    static func printDownloadChecklist() {
        print("=== Biblical Art Download Checklist ===")
        print("Add images to: Resources/Assets.xcassets/BiblicalArt/")
        print("Name format: biblical_<key>.imageset")
        print("All listed artists are public domain — source from Wikimedia Commons\n")

        let total = allKeys.count
        let found = allKeys.filter { hasImage(for: $0) }.count
        print("Progress: \(found)/\(total) images bundled\n")

        // Print prioritized missing list first — this is the action list.
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("MISSING IMAGES (sourced in tier order)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        let entryByKey = Dictionary(uniqueKeysWithValues: allEntries.map { ($0.key, $0) })
        var listedKeys: Set<String> = []

        for (_, label, keys) in acquisitionPriority {
            let missing = keys.filter { !hasImage(for: $0) }
            guard !missing.isEmpty else { continue }
            print(label)
            for key in missing {
                guard let entry = entryByKey[key] else { continue }
                print("  ⬜ biblical_\(entry.key)")
                print("     \"\(entry.title)\" — \(entry.artist)")
                listedKeys.insert(key)
            }
            print("")
        }

        // Catch any catalog entries not in the priority list.
        let unlisted = allEntries.filter { !hasImage(for: $0.key) && !listedKeys.contains($0.key) }
        if !unlisted.isEmpty {
            print("UNRANKED — additional missing entries")
            for entry in unlisted {
                print("  ⬜ biblical_\(entry.key) — \"\(entry.title)\" by \(entry.artist)")
            }
            print("")
        }

        // Bundled (✅) section by category for reference.
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("ALREADY BUNDLED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        for (category, entries) in catalog.sorted(by: { $0.key < $1.key }) {
            let bundled = entries.filter { hasImage(for: $0.key) }
            guard !bundled.isEmpty else { continue }
            print("## \(category)")
            for entry in bundled {
                print("  ✅ biblical_\(entry.key) — \"\(entry.title)\" by \(entry.artist)")
            }
            print("")
        }
    }
}
