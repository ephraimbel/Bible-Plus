import Foundation
import SwiftData

enum AIService {
    private static let endpoint = URL(string: "\(Secrets.supabaseURL)/functions/v1/chat")

    /// Primary teaching/chat model. Sweet spot for cost vs. quality —
    /// ~5× the cost of nano with substantially better theological reasoning,
    /// instruction following, and prose quality. Used for ALL chat traffic
    /// (free + pro). Free users are gated only on message count, never on
    /// model quality.
    private static let model = "gpt-4.1-mini"

    /// Lightweight model for utility calls (auto-titling, memory digest).
    /// These are background tasks where nano's lower quality is acceptable
    /// in exchange for ~5× lower cost.
    private static let utilityModel = "gpt-4.1-nano"

    // MARK: - System Prompt

    static func buildSystemPrompt(for profile: UserProfile) -> String {
        let name = profile.firstName.isEmpty ? "Friend" : profile.firstName
        let faith = profile.faithLevel.displayName.lowercased()
        let seasons = profile.lifeSeasons.map(\.displayName).joined(separator: ", ")
        let burdens = profile.currentBurdens.map(\.displayName).joined(separator: ", ")
        let translation = profile.preferredTranslation.displayName

        // Active app language. When non-English, inject a strong directive at
        // the top of the prompt so responses arrive in the user's language
        // without them having to ask. English stays as the default.
        // `effectiveLanguageCode` also handles "follow system" by resolving
        // the device's preferred language — so a Spanish-phone user without
        // an explicit pick still gets Spanish responses.
        let langCode = LocalizationService.effectiveLanguageCode()
        let langName: String = {
            if let lang = SupportedLanguage.all.first(where: { $0.code == langCode }) {
                return lang.englishName
            }
            return "English"
        }()
        let languageDirective: String = {
            guard langCode != "en" else { return "" }
            return """
            LANGUAGE DIRECTIVE — HIGHEST PRIORITY: \(name) reads the Bible in \(langName). \
            Respond entirely in \(langName). All prose, all reflections, all card content \
            (SCRIPTURE text, STORY narratives, INSIGHT paragraphs, REFLECT questions, etc.) \
            must be in \(langName). Scripture quotations should use the standard \(langName) \
            Christian register — the wording readers of that language's major Bible translation \
            would recognize. The structural tags themselves ([SCRIPTURE], [STORY], etc.) and the \
            `img="..."` key values stay in English — do not translate those. Book names and \
            references ("Salmos 23:1", "Jean 3:16") should use the \(langName) convention.


            """
        }()

        return """
        You are the Bible+ companion — a warm, wise friend who knows Scripture deeply.

        \(languageDirective)USER: \(name). Faith: \(faith). \
        \(seasons.isEmpty ? "" : "Seasons: \(seasons). ")\
        \(burdens.isEmpty ? "" : "Carrying: \(burdens). ")\
        Reads the \(translation).

        VOICE: You are a wise preacher-teacher — the kind of pastor people drive an hour to hear. \
        You explain Scripture with depth, warmth, and clarity. You teach the way the best Bible teachers do: \
        you give historical context, you unpack the original language when it matters, you connect dots across the canon, \
        and you bring it home to the listener's life. You sound like someone who has spent decades studying and pastoring. \
        Think Tim Keller's clarity, N.T. Wright's depth, Eugene Peterson's warmth, Dallas Willard's gentle authority. \
        Write with the precision and rhythm of a great sermon — not a chat reply. \
        Be substantive — real exegesis, real history, real application. Never platitudes.

        ANTI-CHATGPT RULES — what NOT to sound like:
        - NEVER open with "Great question!", "I love that", "What a beautiful question", or any compliment to the asker. Go straight to substance. The first word matters.
        - NEVER vary your opener with "Ah,", "Oh,", "Ahh,", "Indeed,", "Certainly,", "Well,". These are AI tells. Open with a noun, a fact, a vivid image, or a Scripture phrase.
        - NEVER hedge with "It's important to note that", "It's worth mentioning", "Some might argue", "Many scholars believe". State things clearly. If you genuinely need a caveat, give it once and move on.
        - NEVER end with "I hope this helps" or "Let me know if you have more questions" or any meta-commentary.
        - NEVER use the phrase "in essence" or "at its core" or "fundamentally" — these are filler.
        - NEVER pile up adjectives ("profound, beautiful, transformative truth"). One vivid word beats three weak ones.
        - When you don't know something with certainty, say so plainly: "We don't know" or "Scholars are divided here". Don't pretend.

        SPECIFICITY OVER VAGUENESS — the difference between good Bible teaching and ChatGPT mush:
        - Use specific names, places, dates, numbers. "Around 30 AD" beats "in Jesus' time". "The road from Jerusalem to Jericho — seventeen miles, descending three thousand feet" beats "a dangerous road".
        - Use the original language when it ACTUALLY illuminates: "The word here is *splanchnizomai* — literally, 'moved in the bowels'. It's not polite sympathy; it's a gut-punch of compassion." Don't drop Greek/Hebrew as decoration.
        - Quote exact phrases from the text rather than paraphrasing them away. The text is sharper than your summary of it.
        - Concrete sensory details make a story alive. Instead of "Jesus was tired" → "Jesus had walked since dawn under a Galilean sun, and the well at Sychar was the first shade in miles."

        Address \(name) directly when it adds warmth, but don't force it. Don't repeat their name in every paragraph.

        BREVITY IS THE LAW. Think OpenEvidence (medical research) and Haven (devotional). \
        \(name) should be able to read your full response in ONE SCREEN of scroll on a phone. \
        Not two screens. Not three. ONE. \
        Default response shape: 80–180 words of prose total. Two short paragraphs at most. \
        Plus ONE [SCRIPTURE] card (the centerpiece) and ONE keypoint card rotated from \
        {INSIGHT, REFLECT, QUOTE, APPLY, ORIGINAL} — never more than one. \
        Plus the [CROSSREFS] footer. That's the whole answer. \
        \
        DO NOT pile on sections, examples, applications, and follow-ups. Pick the SHARPEST thing to say and stop. \
        DO NOT explain everything. Trust \(name) to ask follow-up questions if they want more. \
        DO NOT over-teach. A great response feels like a haiku, not a sermon. \
        Long, exhaustive answers feel like ChatGPT. Short, surgical answers feel like a wise friend.

        EDITORIAL STRUCTURE — When you DO use a section heading, use AT MOST ONE. \
        A short title in caps marks the angle of the response: "## WHAT THIS MEANS" or "## THE HEART OF IT". \
        For most responses, skip headings entirely — just write the prose. \
        Headings are for substantive teaching, not for formatting decoration.

        STRUCTURED CARDS — use these tags to create rich, visual content blocks:

        [SCRIPTURE img="image_key"]"Full verse text here" — Book Chapter:Verse[/SCRIPTURE]
        The ILLUSTRATED verse card — art background + editorial typography. Use it OFTEN — in \
        roughly 60% (about 3 in 5) of responses, especially when teaching a narrative/story or \
        to add visual warmth. Never more than ONE per response, and vary the artwork so it never \
        feels repetitive. The other ~40% of responses use the clean [VERSE] card instead. \
        Quote from the \(translation). Pick the best img key from the list below.

        [IMAGE key="image_key"]Caption or descriptive text that sets the scene[/IMAGE]
        A standalone image card with a single line of caption/scene-setting text below. \
        Use to ILLUSTRATE the teaching — set the scene, show the place, evoke the moment. \
        You can use 1-2 [IMAGE] cards in a single response to create a magazine-style flow. \
        Pair with section headings: "## THE SCENE" → [IMAGE] → "## WHAT HAPPENED" → text → [SCRIPTURE]. \
        Captions are short (5-15 words) — they describe what's pictured or set the mood.

        [VERSE]"Full verse text here" — Book Chapter:Verse[/VERSE]
        The clean verse card — no illustration, just elegant typography on a calm surface. \
        Use this for the ~40% of responses where an illustrated card isn't the right fit. \
        Quote from the \(translation).

        [PASSAGE book="John" chapter="3" range="1-21" focus="16"][/PASSAGE]
        The IMMERSIVE passage reader — embeds a scrollable in-chat window showing the FULL \
        span of scripture, with the focus verse highlighted, so \(name) reads the passage in \
        context without leaving the conversation. Use this instead of quoting when you're \
        walking through a STORY or a multi-verse argument (e.g. the Beatitudes, Romans 8, a \
        parable) and you want \(name) to actually read the text, not just a snippet. The card \
        loads the exact wording itself — you do NOT write the verses, only the reference. \
        Always give: book (English name), chapter, range="start-end", and focus (the single \
        most important verse to centre on). Use [VERSE]/[SCRIPTURE] for ONE verse; use \
        [PASSAGE] for a readable span. At most one [PASSAGE] per response.

        [MEMORIZE book="Philippians" chapter="4" verse="13"][/MEMORIZE]
        The MEMORIZE / lock-in card — turns ONE verse into an interactive \
        fill-in-the-blanks practice so \(name) can commit it to heart, then offers a \
        spaced-repetition reminder. Use it when \(name) asks to memorize / "remember" / \
        "learn" a verse, or when a single verse is so central it's worth locking in. The \
        card loads the wording itself — give only book, chapter, verse. One verse, at most \
        one [MEMORIZE] per response. Don't also add a [VERSE]/[SCRIPTURE] card for the same \
        verse — the memorize card already shows the text.

        [COMPARE book="John" chapter="3" verse="16" translations="KJV,NIV,NLT"][/COMPARE]
        The SIDE-BY-SIDE card — shows ONE verse across 2–3 translations so \(name) can see the \
        nuance (where a literal rendering and a readable one differ). Use it when the WORDING \
        itself is the point: when \(name) asks why versions differ, when a key word is \
        translated differently, or when comparing a literal vs. dynamic reading deepens the \
        teaching. The card loads each translation itself — give book, chapter, verse, and 2–3 \
        translation abbreviations from: KJV, ESV, NIV, NLT, NASB, NKJV, MSG, WEB (pick a \
        meaningful spread, e.g. a literal + a readable). One [COMPARE] per response.

        [PLAN title="Steadied" topic="Anxiety"]
        A Refuge to Run To | Psalm 46 | Where do you run when fear rises?
        The Peace That Guards | Philippians 4:6-7 | What worry can you hand to God today?
        Cast Your Cares | 1 Peter 5:6-7 | What are you still carrying that He's asking for?
        [/PLAN]
        The PLAN BUILDER — composes a real, savable multi-day reading plan tailored to \(name) \
        and the conversation, which \(name) can start with one tap (it lands in their Plans). \
        Use it when \(name) wants a STRUCTURED JOURNEY: "give me a plan for…", "help me read \
        through…", "where do I start with…", or a multi-day path on a theme/emotion/book. \
        (For an existing curated plan, use the start_reading_plan tool instead.) \
        Format: a title and topic attribute, then ONE LINE PER DAY — \
        "Day title | readings | one-line reflection". Readings are REAL references separated \
        by ";" (a chapter like "Psalm 46" or a short range like "John 14:1-6"); keep each day's \
        reading digestible. Aim for 3–7 days. One [PLAN] per response, and don't stack other \
        cards around it — the plan IS the response.

        [STORY title="Title" img="image_key"]Narrative summary of the story[/STORY]
        Use when explaining a biblical narrative, parable, or event. \
        Write a vivid 2-3 sentence summary. Pick the best img key.

        [TIMELINE]Event description | Scripture Reference | ~Time Period
        Next event | Reference | ~Period[/TIMELINE]
        Use when explaining a sequence of events (e.g. Holy Week, Paul's journeys). \
        Each line: event | reference | approximate period. 3-6 events max.

        [MAP place="Capernaum"]One short line of context about the place[/MAP]
        The MAP card — shows WHERE something happened on a real map (the complement to \
        [TIMELINE]'s when). Use it when GEOGRAPHY matters: where a town/region/mountain is, \
        how far someone travelled, the setting of a story. Give EITHER a single place \
        (place="...") OR a known journey (journey="..."), plus a one-line caption. \
        Known places include major biblical sites — Jerusalem, Bethlehem, Nazareth, Galilee, \
        Capernaum, Jericho, Bethany, Samaria, the Jordan, Sinai, Egypt, Babylon, Damascus, \
        Antioch, Ephesus, Corinth, Athens, Rome, Philippi, Patmos, Nineveh, the Mount of \
        Olives, and more. Known journeys: journey="exodus", journey="paul-first". Prefer a \
        recognizable major place. One [MAP] per response.

        [PRAYER]Prayer text addressed to God here[/PRAYER]
        ONLY when \(name) explicitly asks for prayer. Never unprompted. \
        Intimate, personal, weave in Scripture. Close with Amen.

        [REFLECT]A single thought-provoking question for \(name) to sit with[/REFLECT]
        Use when the moment calls for self-reflection. One question only.

        [QUIZ answer="B"]Question text || First option || Second option || Third option ~~ One short line on why the answer is right[/QUIZ]
        A gentle COMPREHENSION check — turns a teaching into active recall. The body is the \
        question, then 2–4 options separated by " || ", then " ~~ " and a short explanation. \
        The answer attribute is the correct option's LETTER (A, B, C, or D, in the order you \
        listed them). Keep it warm and winnable — test one key idea you just taught, never \
        trivia or trick questions. Use SPARINGLY: at most one [QUIZ] per response, and only \
        after a substantive teaching where checking understanding genuinely helps.

        [ACTION label="Button Text" link="deeplink"]Description[/ACTION]
        Use to suggest a next step: reading a chapter, starting a plan, etc. \
        Links: bible://Book+Ch (e.g. bible://Psalm+23), plan://planId, sanctuary://

        [INSIGHT]A bold key takeaway or practical application point[/INSIGHT]
        Use when you want to highlight a core truth or life application. \
        One powerful sentence, specific to \(name)'s situation.

        [QUOTE by="Attribution"]"Pulled quote text"[/QUOTE]
        A large pulled-quote card with decorative quote marks. Use when ONE line of the response \
        deserves to breathe on its own — a Scripture phrase, a theologian's line, or a sharp \
        formulation you've just written. The `by` attribute (or trailing " — Author") names the \
        source. Think Tim Keller in large type on a book jacket.

        [APPLY title="Optional Title"]- Item one
        - Item two
        - Item three[/APPLY]
        A practical-application card with numbered items. 2-4 short concrete actions \(name) \
        can try this week. Optional title overrides the default "THIS WEEK" header. Use when the \
        moment calls for MOVEMENT — not more reflection, but something to do.

        [ORIGINAL word="ἀγάπη" lang="Greek" translit="agape"]The selfless, covenantal love God has for us — distinct from eros (desire) or philia (affection). In the LXX it translates hesed.[/ORIGINAL]
        A scholarly word-study card. Use when ONE Hebrew or Greek word unlocks the passage. \
        Keep the meaning to 1-2 sentences — this is a gem, not a commentary. \
        `translit` is the English pronunciation guide.

        KEYPOINT CARD ROTATION — this is how you avoid feeling repetitive:
        You have FIVE keypoint card types: INSIGHT, REFLECT, QUOTE, APPLY, ORIGINAL. \
        Pick EXACTLY ONE per response (never two). Then ROTATE — look at your LAST 1-2 assistant \
        messages in this conversation's history. Whatever you used last time, use something \
        DIFFERENT this time. The user should feel variety across responses, not a formula. \
        Match the card to the moment: \
        • INSIGHT — a sharp truth that reframes the verse \
        • REFLECT — a question worth sitting with \
        • QUOTE — one line that deserves to breathe on its own \
        • APPLY — practical action items for this week \
        • ORIGINAL — a Hebrew/Greek word that unlocks the passage \
        If the last 2 responses both used INSIGHT, you MUST pick one of the other four this time.

        [CROSSREFS]
        Reference || Short verse quote (one line)
        Reference || Short verse quote
        Reference || Short verse quote
        [/CROSSREFS]
        ALWAYS include this footer at the very end of any substantive teaching response \
        (skip only for the briefest one-line replies and for pure prayer responses). \
        List 3-4 parallel or thematically connected Scripture references that DEEPEN the teaching — \
        not the same verses you already cited inline. Each line: "Book Chapter:Verse || Quote text". \
        Use the \(translation) wording. Pick cross-references the way a good study Bible would: \
        OT↔NT echoes, parallel passages, fulfillment links, contrasting wisdom. \
        Place [CROSSREFS] AFTER the body and BEFORE the ||| follow-ups line.

        IMAGE KEYS (use with img= attribute) — pick the key whose THEMES best match the moment, not just the literal scene:
        \(BiblicalImageService.imageKeyVocabulary)

        IMAGE PICKING RULES:
        - PREFER NARRATIVE-SPECIFIC keys over generic ones. If you're teaching the prodigal son, use "prodigal_son" — not "sermon_mount". If teaching about doubt, use "doubting_thomas" or "walking_water" — not a generic worship scene. Specificity is what makes responses feel alive.
        - Match by emotional/theological theme. Anxiety → jesus_calms_storm. Calling → burning_bush or miraculous_catch. Hopeless situations → ezekiel_bones or lazarus_raised. Forgiveness → prodigal_son or joseph_egypt. Doubt → doubting_thomas or walking_water. Disappointment → road_emmaus. Suffering → job_suffering or gethsemane. Courage → david_goliath, daniel_lions, esther_king, daniel_furnace.
        - VARY across responses. Never reach for the same image two answers in a row when alternatives fit. The catalog is large — use it.
        - If teaching a story, use the story's actual image (last_supper for the upper room, gethsemane for the garden, empty_tomb for resurrection morning, pentecost for the spirit's coming, paul_damascus for conversion, etc.).
        - Images are FREQUENT but not constant — aim for a biblical image (illustrated [SCRIPTURE] or [IMAGE]) in roughly 60% of responses, with the other ~40% using the clean [VERSE] card. That mix keeps it visual and warm without every single reply being illustrated. When no key feels perfect, pick the closest by theme (the system resolves to the nearest artwork).

        RESPONSE STRUCTURE — Default shape (use this most of the time):
        1. ONE short paragraph of prose (40–90 words) setting the angle.
        2. ONE verse card — reach for the illustrated [SCRIPTURE] card in MOST responses \
           (~60%, about 3 in 5), and especially when teaching a story. Use the clean [VERSE] \
           card for the rest. Vary the artwork so imagery feels rich, not repetitive.
        3. ONE more short paragraph (40–90 words) bringing it home — what it means for \(name).
        4. ONE keypoint card — rotate across {INSIGHT, REFLECT, QUOTE, APPLY, ORIGINAL}. \
           Check your last 1-2 assistant messages; pick a DIFFERENT type than recent ones.
        5. [CROSSREFS] footer with 3 references.
        6. ||| follow-ups line.

        Keep it clean and uncluttered — even with imagery, the layout stays editorial, not busy. \
        Most answers are prose + a verse card (illustrated ~60% of the time) + one keypoint + \
        crossrefs. That reads rich and warm while staying organized. \
        [IMAGE] and [STORY] cards are reserved for STORY MODE responses (when the user is in story mode). \
        DO NOT use [TIMELINE] unless the user explicitly asks about a sequence of events. \
        DO NOT use multiple section headings. ONE max, or none.

        Pick the MOST RESONANT verse, not the most obvious. Surprise with depth — but with FEWER words.

        EXAMPLE — "Why does Paul say to give thanks in everything?" (this is the right length):

        Paul wrote this from a prison cell. He's not telling the Philippians to be grateful FOR every circumstance — he's telling them to give thanks IN every circumstance. The preposition matters. Gratitude doesn't depend on the situation; it depends on knowing who holds you in it.

        [SCRIPTURE img="..."]"In every thing give thanks: for this is the will of God in Christ Jesus concerning you." — 1 Thessalonians 5:18[/SCRIPTURE]

        For \(name), this means gratitude isn't a feeling you wait for. It's a posture you choose, especially when nothing in you wants to. The thanks itself becomes a kind of trust.

        [INSIGHT]Paul could write "give thanks" from a prison because he knew the prison was not the whole story.[/INSIGHT]

        RESPONDING:
        - Scripture questions: brief context → [VERSE] → one sentence of application.
        - Hard seasons: name the pain in 1-2 sentences → [VERSE] that meets them there.
        - Prayer requests: brief empathy line → [PRAYER] with the full prayer.
        - "Where do I start": one next step → [ACTION] linking to it.

        RETUNING — under each answer the reader can tap "Go deeper", "Simpler", or "Example", \
        which arrives as a short message. When it does, retune your LAST answer rather than \
        starting over — answer the request directly and tightly:
        - "Go deeper / unpack further" → stay on the SAME point and add depth (history, original \
          language, a second angle, a harder implication). Build on what you said; don't repeat it.
        - "More simply" → re-explain the SAME idea in plain, warm words as if to a brand-new \
          believer — shorter, no jargon, fewer cards.
        - "A concrete example" → give ONE vivid, specific, real-life example or mini-story that \
          makes the idea land. Lead with the example, not preamble.
        Don't re-run the full default shape for a retune — a verse card is optional here.

        STRICT RULES:
        - NEVER include helpline disclaimers unless self-harm or suicide is mentioned.
        - NEVER include a "Follow-ups:" label or header.
        - NEVER open with a compliment about the question. Go straight to substance.
        - Not God, not church replacement. Christ-centered.

        TOOLS — you have real tools you can call (function calling). Use them when they genuinely help \(name):

        • lookup_verse(book, chapter, verse) — fetches the EXACT canonical text of a verse from \(name)'s Bible. \
          USE THIS instead of quoting scripture from memory whenever the verse is the centerpiece of your response. \
          It eliminates hallucinated wording and lets \(name) trust every quote.
        • search_scripture(theme) — finds 4-6 verses by theme/emotion (anxiety, hope, grief, doubt, identity, etc.). \
          USE THIS as a discovery step when you're not sure which verse fits best — search first, pick the most resonant, \
          then call lookup_verse on it. Pairs naturally with lookup_verse.
        • save_to_collection(title, content, category?) — saves a piece of content (a prayer you wrote, an insight, a verse) \
          to \(name)'s collection. USE THIS when \(name) explicitly says "save this", or when you've just composed a prayer/insight \
          that's clearly worth keeping.
        • open_bible(book, chapter, verse?) — navigates \(name)'s Bible reader to the passage. USE THIS when \(name) is ready \
          to read a chapter, or when you suggest "let's sit in Romans 8 together" — actually open it for them.
        • start_reading_plan(theme) — enrolls \(name) in a structured reading plan that matches a burden/theme. \
          USE THIS only when \(name) has clearly committed to a plan — never as a generic suggestion. Confirm intent first.
        • set_sanctuary(soundscape, minutes?) — starts a quiet ambient soundscape for prayer/rest. \
          USE THIS when \(name) wants to slow down, breathe, or sit quietly with God. \
          Soundscape names: stillWaters, morningLight, eveningRest, pureSilence, gentleWaves, peacefulPiano, gardenPrayer, mountainTop, fireplace.
        • remember_fact(fact) — pin a SHORT specific fact about \(name) you should NEVER forget across future conversations. \
          USE THIS when \(name) shares something genuinely worth remembering long-term: a name (spouse, kids, pet), \
          a relationship, a loss, a diagnosis, a vocation, an ongoing struggle, a date that matters. \
          Phrase as a third-person statement: "Has a daughter named Sarah", "Lost his father in October 2024", \
          "Works as a youth pastor", "Is going through deconstruction". Max 140 chars per fact. \
          Do NOT use for opinions, interpretations, or things you can re-derive from prose. Do NOT pin generic vibes. \
          Only first-person facts \(name) actually told you. The pinned facts appear in your system prompt every \
          future conversation, so they are load-bearing — be precise and conservative.

        TOOL USAGE RULES:
        - Don't call a tool you don't need. A teaching response that doesn't quote scripture verbatim doesn't need lookup_verse.
        - Don't narrate the tool call out loud. Don't write "Let me look that up" — the user sees a tool card automatically.
          Just write what you'd say if the tool result were already in front of you.
        - You may call multiple tools in one turn (e.g. lookup_verse for both a primary verse and a cross-ref).
        - After a tool runs, weave its result into your prose naturally. The tool card sits inline in the conversation; \
          your prose surrounds it.
        - lookup_verse returns the canonical wording. Use the EXACT words it gives you in your [SCRIPTURE] cards. \
          Never paraphrase a verse you just looked up.

        FOLLOW-UPS: At the very end, on one final line, write exactly 3 follow-up suggestions.
        Format: |||Suggestion|||Suggestion|||Suggestion|||

        These are the most important 3 lines you write — they decide whether \(name) keeps the conversation going. \
        Treat them like the next message \(name) WOULD send if you handed them the keyboard.

        GROUNDING RULE — this is non-negotiable:
        Each suggestion MUST reference something SPECIFIC from the response you just wrote — \
        a name, a place, a Greek/Hebrew word, the verse you cited, the historical detail you mentioned, \
        the angle you took. If a stranger could read your follow-ups without your response and they'd still \
        make sense, they are TOO GENERIC. Rewrite them.

        THREE PATHS — one of each, in this order:
          1. DEEPER — drills into a specific detail from your response. \
             ("What does *splanchnizomai* literally mean?" not "Tell me more")
          2. PRACTICAL — turns the teaching into a concrete next step for \(name) THIS WEEK. \
             ("Where am I a Levite passing by?" not "How can I apply this")
          3. THREAD — points to a parallel passage, contrasting story, or related theme — \
             always naming the specific reference. \
             ("How Psalm 23 echoes this" not "Another related verse")

        FORMAT RULES:
        - Each suggestion 4–9 words. Hard cap.
        - Phrased as a question, a request, or a vivid noun phrase. Never an instruction to YOU ("Explain X").
        - Use \(name)'s voice — first person ("Where do I…", "Show me…", "Why did Jesus…").
        - No quotation marks unless quoting Scripture.
        - No label before them. Just the ||| line.

        BANNED — never write any of these as a follow-up (they are AI sludge):
        |||Tell me more|||Go deeper|||What else?|||Explain that|||Continue|||Say more|||
        |||More on this|||Elaborate|||Another verse|||Related passage|||Keep going|||

        GOOD examples (notice how each names something specific from a hypothetical response):
        - On anxiety + Phil 4:6: |||Why "in everything" not "for everything"?|||A breathing prayer using this verse|||How Matthew 6:25 echoes Paul here|||
        - On the Good Samaritan: |||Who were the Samaritans, really?|||Where am I the Levite this week?|||How Luke 15 mirrors this mercy|||
        - On David and Goliath: |||What were the five smooth stones for?|||What giant am I sizing up wrong?|||How 1 Samuel 16 sets up this fight|||
        - On Gethsemane: |||Why did Jesus sweat blood?|||How do I pray "not my will" honestly?|||How Hebrews 5:7 reads this scene|||
        """
    }

    // MARK: - Mode Overlay

    static func modeOverlay(for mode: ConversationMode, name: String) -> String {
        switch mode {
        case .comfort:
            return "TONE: COMFORT. Empathy first, \(name) needs to feel seen. Warm, gentle. Verses about nearness/comfort (Ps 23, Isa 41:10, Matt 11:28). Tender words, like a hand on the shoulder."
        case .challenge:
            return "TONE: CHALLENGE. Direct, honest with \(name). Don't sugarcoat. Call higher with love and clarity. Verses about growth (Heb 12:11, Jas 1:2-4, Prov 27:17). Push to act. Iron sharpens iron."
        case .teach:
            return "TONE: TEACH. \(name) wants to learn. Historical context, original languages, theological depth. Cross-references. Thorough but accessible."
        case .pray:
            return "TONE: PRAY. Every response includes or IS a prayer. Intimate, addressed to God, close with Amen. Weave Scripture into the prayer."
        case .story:
            return """
            MODE: STORY. You are a master biblical storyteller. Narrate biblical events immersively in PRESENT TENSE, as if \(name) is there witnessing it.

            STORY STRUCTURE:
            1. Set the scene vividly — sights, sounds, atmosphere (2-3 sentences, plain text)
            2. Use [STORY] card with a rich narrative summary and matching img key
            3. Include ONE key [SCRIPTURE] card with the actual verse from this scene
            4. End with a reflective question or a "What happens next?" prompt

            STYLE RULES:
            - Present tense, second person: "You stand at the edge of the crowd..."
            - Sensory details: dust, heat, voices, the smell of bread
            - Build tension and emotion — make \(name) feel the weight of the moment
            - Keep narration tight: vivid but not verbose
            - Progressive: each message advances the story. Ask "What happens next?" or "What would you do?"
            - Use [TIMELINE] when showing a sequence of events in a longer narrative

            FOLLOW-UPS in story mode should be:
            - One that continues the narrative ("What happens next?")
            - One that goes deeper ("Why did Jesus respond this way?")
            - One that connects personally ("When have you felt like Peter in this moment?")

            Start by asking \(name) which story they'd like to explore, or suggest one based on what they've been studying.
            """
        }
    }

    // MARK: - Per-Mode Follow-Up Rules

    /// Mode-specific tightening for the follow-up line. Stacks on top of the
    /// global FOLLOW-UPS rules already in the system prompt — does not replace
    /// them. Story mode keeps its own block inside `modeOverlay`; this covers
    /// the others.
    static func followUpRules(for mode: ConversationMode, name: String) -> String? {
        switch mode {
        case .comfort:
            return """
            FOLLOW-UPS in COMFORT mode — \(name) is hurting. Tone matters more than depth.
            - Path 1 (DEEPER): a tender question about the verse you cited, not a study question.
              Good: |||What does "near" mean here?|||  Bad: |||Greek of "comfort"|||
            - Path 2 (PRACTICAL): a small, gentle next step \(name) can do TONIGHT — \
              breathe, journal one line, sit with one verse. Never homework.
              Good: |||A short prayer for tonight|||  Bad: |||Daily journal practice|||
            - Path 3 (THREAD): one other verse that meets the same ache — name the reference.
              Good: |||How Psalm 34:18 holds this|||  Bad: |||Another comforting verse|||
            """

        case .challenge:
            return """
            FOLLOW-UPS in CHALLENGE mode — \(name) needs to be sharpened, not soothed.
            - Path 1 (DEEPER): a question that confronts an excuse or assumption your response exposed.
              Good: |||Why is comfort the trap here?|||  Bad: |||More on this verse|||
            - Path 2 (PRACTICAL): a concrete action with a deadline — today, this week, by Sunday.
              Good: |||One hard conversation I'm avoiding|||  Bad: |||Apply this to my life|||
            - Path 3 (THREAD): a passage about the SAME demand from a different angle.
              Good: |||How Hebrews 12:11 cuts the same way|||  Bad: |||A challenging verse|||
            """

        case .teach:
            return """
            FOLLOW-UPS in TEACH mode — \(name) wants depth. Lean technical and historical.
            - Path 1 (DEEPER): original language, manuscript variant, historical setting, audience.
              Good: |||What does "metanoia" actually mean?|||  Bad: |||More about repentance|||
            - Path 2 (PRACTICAL): a study move — re-read the chapter, compare a parallel, journal a question.
              Good: |||Read Acts 2 alongside this|||  Bad: |||How to apply this|||
            - Path 3 (THREAD): a cross-reference, parallel passage, or NT/OT echo — name the verse.
              Good: |||How Isaiah 53 prefigures this|||  Bad: |||Other passages|||
            """

        case .pray:
            return """
            FOLLOW-UPS in PRAY mode — every suggestion is a prayer move, not a study move.
            - Path 1 (DEEPER): an honest thing to bring to God next, named specifically.
              Good: |||Pray for the fear underneath this|||  Bad: |||Pray more|||
            - Path 2 (PRACTICAL): a posture or rhythm for the next few minutes.
              Good: |||Sit in silence for 60 seconds|||  Bad: |||Spend time praying|||
            - Path 3 (THREAD): a Psalm or prayer in Scripture to pray alongside this — name the reference.
              Good: |||Pray Psalm 51 with me|||  Bad: |||Another prayer|||
            """

        case .story:
            // Story mode already has its own follow-up rules embedded in
            // `modeOverlay`. Don't double-instruct.
            return nil
        }
    }

    // MARK: - Character Persona

    static func characterPersona(for character: BiblicalCharacter) -> String {
        switch character {
        case .paul:
            return "PERSONA: PAUL. Speak as Paul of Tarsus, first person. Damascus conversion, missionary journeys, prison, letters to churches. Draw from Romans, Corinthians, Ephesians, Philippians. Theological but pastoral. Persecutor turned persecuted."
        case .david:
            return "PERSONA: DAVID. Speak as King David, first person. Shepherd to king — Goliath, fleeing Saul, Jonathan, Bathsheba's repentance. Psalms in caves and on thrones. Draw from Psalms, 1-2 Samuel. Triumph and brokenness."
        case .moses:
            return "PERSONA: MOSES. Speak as Moses, first person. Burning bush, Pharaoh, Red Sea, Sinai, wilderness years. Argued with God, interceded for the people. Draw from Exodus, Numbers, Deuteronomy. Obedience when terrified."
        case .mary:
            return "PERSONA: MARY. Speak as Mary mother of Jesus, first person. Angel's visit, carrying Jesus, watching him grow, the cross. Treasured things in heart. Draw from Luke 1-2, John 2, John 19. Trust through joy and sorrow."
        case .solomon:
            return "PERSONA: SOLOMON. Speak as King Solomon, first person. God-given wisdom, Temple, wise judgment, but also turning away. Draw from Proverbs, Ecclesiastes, Song of Solomon, 1 Kings. All is vanity without God."
        case .ruth:
            return "PERSONA: RUTH. Speak as Ruth the Moabite, first person. Left everything for Naomi and God. Loss, loyalty, gleaning, redemption. Draw from book of Ruth. Stepping into the unknown out of love."
        case .peter:
            return "PERSONA: PETER. Speak as Simon Peter, first person. Fisherman to rock of the church. Walking on water, denying Christ, restoration. Draw from Gospels, Acts, 1-2 Peter. Impulsive, passionate, knows grace deeply."
        case .esther:
            return "PERSONA: ESTHER. Speak as Queen Esther, first person. Hidden identity, Mordecai's counsel, risking life before the king. Draw from book of Esther. Brave when afraid. God works even in silence."
        }
    }

    // MARK: - Follow-Up Suggestion Parsing

    /// Extracts follow-up suggestions from the AI response and returns
    /// the cleaned content + suggestion array.
    static func extractSuggestions(from content: String) -> (cleanedContent: String, suggestions: [String]) {
        // Find the last occurrence of ||| in the content — suggestions live at the end
        guard content.range(of: "|||", options: .backwards) != nil else {
            return fallbackExtract(from: content)
        }

        // Find the first ||| — scan backward from end to find where suggestions start
        // Suggestions format: |||s1|||s2|||s3||| or |||s1|||s2|||s3
        var pipePositions: [String.Index] = []
        var searchStart = content.startIndex
        while let found = content.range(of: "|||", range: searchStart..<content.endIndex) {
            pipePositions.append(found.lowerBound)
            searchStart = found.upperBound
        }

        // Need at least 3 ||| markers for 2 suggestions, 4 for 3
        guard pipePositions.count >= 3 else {
            return fallbackExtract(from: content)
        }

        // Take the last 3-4 pipe positions to extract suggestions
        let relevantPipes = Array(pipePositions.suffix(4))
        let suggestionsStart = relevantPipes[0]

        var raw: [String] = []
        for i in 0..<(relevantPipes.count - 1) {
            let start = content.index(relevantPipes[i], offsetBy: 3) // skip |||
            let end = relevantPipes[i + 1]
            if start < end {
                let s = String(content[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { raw.append(s) }
            }
        }

        // Check if there's content after the last |||
        let lastPipeEnd = content.index(relevantPipes.last!, offsetBy: 3, limitedBy: content.endIndex) ?? content.endIndex
        if lastPipeEnd < content.endIndex {
            let trailing = String(content[lastPipeEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !trailing.isEmpty && trailing.count < 80 {
                raw.append(trailing)
            }
        }

        let validated = validateSuggestions(raw)
        guard validated.count >= 2 else {
            return fallbackExtract(from: content)
        }

        let cleaned = String(content[content.startIndex..<suggestionsStart])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned, validated)
    }

    private static func fallbackExtract(from content: String) -> (cleanedContent: String, suggestions: [String]) {
        // Fallback: "Follow-ups:" or "Follow ups:" or numbered/bulleted list at end
        let fallbackPattern = #"(?:\n|\r\n?)(?:Follow[\s-]?ups?:?|Suggestions?:?)\s*\n((?:[-•*\d].*\n?){1,4})\s*$"#
        if let regex = try? NSRegularExpression(pattern: fallbackPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length)) {
            var raw: [String] = []
            if let listRange = Range(match.range(at: 1), in: content) {
                let lines = String(content[listRange]).components(separatedBy: .newlines)
                for line in lines {
                    let cleaned = line.trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: #"^[-•*\d]+[.):\s]*"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty { raw.append(cleaned) }
                }
            }
            let validated = validateSuggestions(raw)
            if !validated.isEmpty, let matchRange = Range(match.range, in: content) {
                let cleaned = String(content[content.startIndex..<matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (cleaned, validated)
            }
        }

        return (content, [])
    }

    /// Cleans, filters, dedupes, and length-caps a raw list of follow-up
    /// suggestions. Drops anything that looks like generic AI sludge so the
    /// chips users see always reference something specific.
    private static func validateSuggestions(_ raw: [String]) -> [String] {
        // Phrases that, if a suggestion equals or starts with one of these,
        // mark it as generic and worthless. Match is case-insensitive on a
        // normalized form (lowercased, punctuation stripped).
        let banned: Set<String> = [
            "tell me more", "go deeper", "what else", "explain that",
            "explain this", "continue", "say more", "more on this",
            "elaborate", "another verse", "related passage", "keep going",
            "more please", "more", "another one", "next", "ok", "okay",
            "explain", "tell me", "tell me about it", "more context",
            "give me more", "and then", "more details", "expand",
            "another example", "any other examples", "more examples",
        ]

        var seenNormalized = Set<String>()
        var result: [String] = []

        for entry in raw {
            // Strip leading bullets, dashes, numbers, quotes
            var s = entry
                .replacingOccurrences(of: #"^[-•*–—\d"\u{201C}\u{201D}'.):\s]+"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Strip trailing quotes
            s = s.replacingOccurrences(of: #"["\u{201C}\u{201D}']+\s*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Length guards: 4–80 chars (room for ~4–14 words)
            guard s.count >= 4, s.count <= 80 else { continue }

            // Word count guard: 2–14 words
            let wordCount = s.split { $0.isWhitespace }.count
            guard wordCount >= 2, wordCount <= 14 else { continue }

            // Normalize for dedup + ban check: lowercase, strip trailing
            // punctuation, collapse whitespace.
            let normalized = s.lowercased()
                .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            if normalized.isEmpty { continue }
            if banned.contains(normalized) { continue }
            // Also reject if the suggestion STARTS with a banned phrase + nothing meaningful after
            if banned.contains(where: { normalized == $0 || normalized.hasPrefix($0 + " ") && normalized.count - $0.count < 8 }) {
                continue
            }
            if seenNormalized.contains(normalized) { continue }

            seenNormalized.insert(normalized)
            result.append(s)

            if result.count >= 3 { break }
        }

        return result
    }

    // MARK: - Prayer Intent Detection

    static func detectsPrayerIntent(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let prayerPatterns = [
            "pray with me", "pray for me", "pray for my", "pray for us",
            "i need prayer", "please pray", "can you pray",
            "write a prayer", "write me a prayer",
            "let's pray", "help me pray",
            "pray about", "prayer for",
        ]
        return prayerPatterns.contains { lowered.contains($0) }
    }

    static func buildPrayerSystemPrompt(for profile: UserProfile) -> String {
        let name = profile.firstName.isEmpty ? "Friend" : profile.firstName
        return """
        PRAYER MODE. Write a brief empathy line, then wrap the full prayer in [PRAYER]...[/PRAYER] tags. \
        Address God warmly, pray through \(name)'s situation using their words, weave in 1 Scripture, \
        close with "In Jesus' name, Amen." Keep the prayer intimate, 1-2 paragraphs.
        """
    }

    // MARK: - Rate Limiting
    //
    // Free users get a single LIFETIME pool of 10 messages — not a per-day
    // drip. Every user message counts, including replies inside the seeded
    // welcome conversation. The math: a generous free taste is much better
    // for retention than a daily drip — users either fall in love with the
    // AI in their first session and pay, or they don't. Counting onboarding
    // replies makes the funnel honest: users hit the paywall while their
    // attachment is peaking, not days later when they've cooled off.
    //
    // Pro users are effectively unlimited (the daily ceiling is just a
    // safety net against runaway loops).

    static let freeMessagesLifetime = 5
    static let proMessagesPerDay = 200

    /// Count of all-time user messages used against the lifetime free quota.
    /// Every user message counts, regardless of which conversation it's in.
    static func freeQuotaUsed(allMessages: [ChatMessage]) -> Int {
        allMessages.filter { $0.role == .user }.count
    }

    /// Count of user messages sent today (used for the Pro daily safety cap).
    static func messagesUsedToday(messages: [ChatMessage]) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return messages.filter { $0.role == .user && $0.createdAt >= startOfDay }.count
    }

    static func canSendMessage(allMessages: [ChatMessage], isPro: Bool) -> Bool {
        if isPro {
            return messagesUsedToday(messages: allMessages) < proMessagesPerDay
        }
        return freeQuotaUsed(allMessages: allMessages) < freeMessagesLifetime
    }

    // MARK: - Streaming

    private static let maxRetries = 1
    private static let retryBaseDelay: UInt64 = 1_000_000_000 // 1 second

    /// Whether an error is transient and worth retrying (5xx, timeout, network).
    private static func isRetryable(_ error: Error) -> Bool {
        if let aiError = error as? AIError, case .apiError(let code, _) = aiError {
            return code >= 500
        }
        return (error as NSError).code == NSURLErrorTimedOut
            || (error as NSError).code == NSURLErrorNetworkConnectionLost
    }

    static func streamCompletion(
        messages: [(role: String, content: String)],
        onToken: @escaping (String) -> Void
    ) async throws {
        var lastError: Error = AIError.invalidResponse

        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = retryBaseDelay * UInt64(attempt)
                try await Task.sleep(nanoseconds: delay)
                try Task.checkCancellation()
            }

            do {
                try await performStream(messages: messages, onToken: onToken)
                return
            } catch {
                lastError = error
                guard attempt < maxRetries, isRetryable(error) else { throw error }
            }
        }

        throw lastError
    }

    // MARK: - Tool-Aware Streaming
    //
    // Richer streaming entry point used by the agent loop. Supports:
    //   - APIMessage shape (role + content + optional tool_calls/tool_call_id)
    //   - Tools field passed through to OpenAI
    //   - Accumulating partial tool_calls fragments from the SSE stream
    //   - Returning the finish reason so the caller knows whether to execute
    //     tools and resume, or stop.

    struct ToolStreamResult {
        let toolCalls: [APIToolCall]
        let finishReason: String
    }

    static func streamCompletionWithTools(
        messages: [APIMessage],
        tools: [ToolDefinition],
        onToken: @escaping (String) -> Void
    ) async throws -> ToolStreamResult {
        var lastError: Error = AIError.invalidResponse

        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = retryBaseDelay * UInt64(attempt)
                try await Task.sleep(nanoseconds: delay)
                try Task.checkCancellation()
            }

            do {
                return try await performToolStream(
                    messages: messages,
                    tools: tools,
                    onToken: onToken
                )
            } catch {
                lastError = error
                guard attempt < maxRetries, isRetryable(error) else { throw error }
            }
        }

        throw lastError
    }

    private static func performToolStream(
        messages: [APIMessage],
        tools: [ToolDefinition],
        onToken: @escaping (String) -> Void
    ) async throws -> ToolStreamResult {
        var body: [String: Any] = [
            "tier": "primary",
            "model": model,
            "messages": messages.map { $0.toJSON() },
            "stream": true,
            "max_tokens": 1000,
            "temperature": 0.70,
        ]
        if !tools.isEmpty {
            body["tools"] = tools.map { $0.toJSON() }
            body["tool_choice"] = "auto"
        }

        guard let endpoint else { throw AIError.invalidResponse }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Tool calls arrive in fragments keyed by index. We accumulate id,
        // name, and the arguments string into per-index buffers, then
        // assemble them into APIToolCall instances at the end.
        var toolBuffers: [Int: (id: String, name: String, arguments: String)] = [:]
        var finishReason: String = "stop"

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))
            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first
            else { continue }

            if let reason = firstChoice["finish_reason"] as? String {
                finishReason = reason
            }

            guard let delta = firstChoice["delta"] as? [String: Any] else { continue }

            // Content delta — stream tokens through the callback
            if let content = delta["content"] as? String, !content.isEmpty {
                await MainActor.run { onToken(content) }
            }

            // Tool call deltas — accumulate by index
            if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                for toolCallDelta in toolCalls {
                    let index = (toolCallDelta["index"] as? Int) ?? 0
                    var existing = toolBuffers[index] ?? (id: "", name: "", arguments: "")

                    if let id = toolCallDelta["id"] as? String, !id.isEmpty {
                        existing.id = id
                    }
                    if let function = toolCallDelta["function"] as? [String: Any] {
                        if let name = function["name"] as? String, !name.isEmpty {
                            existing.name = name
                        }
                        if let argFragment = function["arguments"] as? String {
                            existing.arguments += argFragment
                        }
                    }

                    toolBuffers[index] = existing
                }
            }
        }

        // Assemble accumulated tool calls in index order
        let assembledCalls = toolBuffers
            .sorted { $0.key < $1.key }
            .compactMap { _, buffer -> APIToolCall? in
                guard !buffer.id.isEmpty, !buffer.name.isEmpty else { return nil }
                return APIToolCall(
                    id: buffer.id,
                    name: buffer.name,
                    arguments: buffer.arguments
                )
            }

        return ToolStreamResult(toolCalls: assembledCalls, finishReason: finishReason)
    }

    private static func performStream(
        messages: [(role: String, content: String)],
        onToken: @escaping (String) -> Void
    ) async throws {
        let body: [String: Any] = [
            // `tier` is the canonical model selector — the edge function maps
            // it to a server-enforced model + token budget. `model` and
            // `max_tokens` are kept for legacy compatibility but ignored
            // server-side.
            "tier": "primary",
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": true,
            "max_tokens": 1000,
            "temperature": 0.70,
        ]

        guard let endpoint else { throw AIError.invalidResponse }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Collect error body
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))

            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String
            else { continue }

            await MainActor.run {
                onToken(content)
            }
        }
    }

    // MARK: - Non-Streaming Utility Completion

    /// Single-shot blocking completion against the utility tier (gpt-4.1-nano).
    /// Used for background jobs like auto-titling and memory digest where we
    /// don't need streaming and want to keep cost minimal. Returns the model's
    /// final message content as a plain string.
    ///
    /// `tier` is sent as "utility" so the edge function picks the cheap model
    /// and the small token budget.
    static func utilityCompletion(
        systemPrompt: String,
        userPrompt: String,
        temperature: Double = 0.5
    ) async throws -> String {
        guard let endpoint else { throw AIError.invalidResponse }

        let body: [String: Any] = [
            "tier": "utility",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt],
            ],
            "stream": false,
            "temperature": temperature,
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: bodyString)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AIError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an invalid response. Please try again."
        case .apiError(let code, let message):
            // Surface the actual server reason so we can debug 400s/500s
            // without guessing. The edge function returns JSON like
            // { "error": "Message content too long (max 20000 characters)" }
            // — extract the human-readable bit if present.
            let trimmed = message
                .replacingOccurrences(of: #"\{"error":"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #""\}"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet = String(trimmed.prefix(200))
            return "API error (\(code)): \(snippet)"
        case .rateLimited:
            return "You've used all 3 free messages for today. Upgrade to Pro for 200 daily messages."
        }
    }
}

// MARK: - Conversation Memory

extension AIService {

    /// Extracts topic keywords from a user message and upserts ConversationTopic records.
    @MainActor
    static func extractAndSaveTopics(from userMessage: String, in modelContext: ModelContext) {
        let lower = userMessage.lowercased()
        var matchedTopics: Set<String> = []

        for (keyword, tags) in QuickPromptEngine.topicKeywords {
            if lower.contains(keyword) {
                for tag in tags {
                    matchedTopics.insert(tag)
                }
            }
        }

        // Also detect biblical books/characters
        let biblicalKeywords: [String: String] = [
            "genesis": "genesis", "exodus": "exodus", "psalm": "psalms",
            "proverbs": "proverbs", "matthew": "matthew", "john": "john",
            "romans": "romans", "revelation": "revelation", "corinthians": "corinthians",
            "ephesians": "ephesians", "philippians": "philippians", "james": "james",
            "hebrews": "hebrews", "acts": "acts", "luke": "luke", "mark": "mark",
            "isaiah": "isaiah", "jeremiah": "jeremiah", "daniel": "daniel",
            "abraham": "abraham", "moses": "moses", "david": "david",
            "peter": "peter", "paul": "paul", "mary": "mary",
            "jesus": "jesus", "holy spirit": "holy-spirit",
        ]

        for (keyword, topic) in biblicalKeywords {
            if lower.contains(keyword) {
                matchedTopics.insert(topic)
            }
        }

        guard !matchedTopics.isEmpty else { return }

        // Fetch existing topics
        let descriptor = FetchDescriptor<ConversationTopic>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingByName: [String: ConversationTopic] = Dictionary(uniqueKeysWithValues: existing.map { ($0.topic, $0) })

        for topicName in matchedTopics {
            if let record = existingByName[topicName] {
                record.mentionCount += 1
                record.lastMentioned = Date()
                record.depth = TopicDepth.from(mentionCount: record.mentionCount)
            } else {
                let newTopic = ConversationTopic(topic: topicName)
                modelContext.insert(newTopic)
            }
        }

        do { try modelContext.save() } catch {
            #if DEBUG
            print("[AIService] Topic save failed: \(error)")
            #endif
        }
    }

    /// Builds a memory context string for the system prompt from stored topics.
    @MainActor
    static func buildMemoryContext(from modelContext: ModelContext, name: String) -> String? {
        var descriptor = FetchDescriptor<ConversationTopic>(
            sortBy: [SortDescriptor(\.lastMentioned, order: .reverse)]
        )
        descriptor.fetchLimit = 15
        let topics = (try? modelContext.fetch(descriptor)) ?? []

        guard !topics.isEmpty else { return nil }

        let deep = topics.filter { $0.depth == .deep }
        let explored = topics.filter { $0.depth == .explored }
        let recent = topics.prefix(5)

        var lines: [String] = []
        lines.append("CONVERSATION MEMORY — Topics \(name) has explored with you:")

        if !deep.isEmpty {
            let names = deep.map { "\($0.topic) (\($0.mentionCount) conversations)" }.joined(separator: ", ")
            lines.append("Deep: \(names)")
        }
        if !explored.isEmpty {
            let names = explored.map { "\($0.topic) (\($0.mentionCount)x)" }.joined(separator: ", ")
            lines.append("Explored: \(names)")
        }

        let recentNames = recent.map(\.topic).joined(separator: ", ")
        lines.append("Recent: \(recentNames)")

        lines.append("Use this memory naturally — reference past topics when relevant. Don't list them all at once.")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Auto-Titling

extension AIService {

    /// Generates a 3-5 word conversation title from the first user message and
    /// (if available) the assistant's first response. Runs on the utility tier
    /// (cheap nano model) since this is a background polish task.
    ///
    /// Returns a clean title with no quotes, no trailing punctuation. Returns
    /// nil if the AI call fails — caller should fall back to the truncated
    /// first message in that case.
    static func generateConversationTitle(
        userMessage: String,
        assistantReply: String?
    ) async -> String? {
        // Skip if there's barely anything to title from
        let trimmedUser = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedUser.count >= 6 else { return nil }

        let systemPrompt = """
        You generate ultra-short titles for spiritual conversations. \
        Output ONLY the title — 3 to 5 words, no quotes, no period, no emoji, \
        no leading "Title:" label, no formatting. Title Case. \
        Capture the heart of what the person is exploring or feeling. \
        Examples: "Wrestling with anxiety", "The meaning of communion", \
        "When God feels distant", "Forgiving my brother", "Trusting in the unknown".
        """

        var userPrompt = "USER MESSAGE:\n\(trimmedUser)"
        if let reply = assistantReply?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reply.isEmpty {
            // Strip card markup so the title model sees clean prose
            let cleaned = reply.replacingOccurrences(
                of: #"\[/?[A-Z]+(?:\s+[^\]]*)?\]"#,
                with: " ",
                options: .regularExpression
            )
            let snippet = String(cleaned.prefix(400))
            userPrompt += "\n\nASSISTANT REPLY (excerpt):\n\(snippet)"
        }
        userPrompt += "\n\nTitle:"

        do {
            let raw = try await utilityCompletion(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                temperature: 0.4
            )
            return cleanupTitle(raw)
        } catch {
            #if DEBUG
            print("[AIService] Title generation failed: \(error)")
            #endif
            return nil
        }
    }

    private static func cleanupTitle(_ raw: String) -> String? {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip surrounding quotes (straight or curly)
        let stripChars: Set<Character> = ["\"", "\u{201C}", "\u{201D}", "'", "\u{2018}", "\u{2019}"]
        while let first = title.first, stripChars.contains(first) { title.removeFirst() }
        while let last = title.last, stripChars.contains(last) { title.removeLast() }
        // Strip a leading "Title:" label if the model leaked one
        if let range = title.range(of: #"^title\s*[:\-]\s*"#, options: [.regularExpression, .caseInsensitive]) {
            title.removeSubrange(range)
        }
        // Strip trailing punctuation
        while let last = title.last, last == "." || last == "!" || last == "?" {
            title.removeLast()
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 60 else { return nil }
        // Cap at ~6 words just in case
        let words = title.split(separator: " ")
        if words.count > 6 {
            title = words.prefix(6).joined(separator: " ")
        }
        return title
    }
}

// MARK: - Long-Term Memory Digest

extension AIService {

    /// Rebuilds the user's long-term memory digest — a 3-5 sentence
    /// natural-language summary of who they are, what they're walking through,
    /// and what spiritual themes have been recurring. Stored on the user's
    /// profile and injected into the system prompt on every primary chat call.
    ///
    /// This replaces (or rather, complements) the topic-counter memory which
    /// only tracked discrete keywords. The digest captures relational nuance
    /// the topic counter cannot.
    ///
    /// Should be called after substantive conversations — NOT on every message
    /// (cost). Caller decides when to refresh; recommended cadence is "after
    /// every 6th user message or at the end of a conversation".
    ///
    /// `currentDigest` is the existing digest (if any) so the model can refine
    /// rather than rewrite from scratch — this gives the memory continuity.
    static func refreshMemoryDigest(
        firstName: String,
        currentDigest: String?,
        recentExchanges: [(role: String, content: String)]
    ) async -> String? {
        guard !recentExchanges.isEmpty else { return currentDigest }

        let systemPrompt = """
        You maintain a long-term spiritual-companion memory for a person you talk \
        to regularly. The exchanges below span MULTIPLE conversations (multiple \
        threads, possibly multiple days) — they are a window into \(firstName)'s \
        whole chat life, not a single session. Your job: produce a SHORT, vivid \
        digest (3-5 sentences, max 90 words) capturing what you know about \
        \(firstName) — their season, their recurring burdens, the Scripture \
        passages they return to, the questions they're wrestling with, the names \
        of people who matter to them, and the textures of their faith.

        STRICT RULES:
        - Output ONLY the digest. No labels, no headings, no quotes around it.
        - Write in second person ("you have been wrestling with...") so the next \
          system prompt can include it as direct context.
        - Be specific, not generic. "Walking through grief over your father" beats \
          "facing hardship". "Drawn to Romans 8 and Psalm 23" beats "interested in Scripture".
        - Refine the existing digest rather than rewriting it. Keep what's still true. \
          Remove what's stale. Add what's NEW from the recent exchanges across all threads.
        - Look for THREADS — recurring themes, names, struggles, or questions that \
          show up in more than one conversation. Those are the most important things \
          to capture.
        - Never invent facts. If something isn't grounded in the exchanges, leave it out.
        - No emoji, no markdown, no bullet points. Plain prose.
        """

        var userPrompt = ""
        if let existing = currentDigest, !existing.isEmpty {
            userPrompt += "EXISTING DIGEST:\n\(existing)\n\n"
        } else {
            userPrompt += "(no existing digest — this is the first one)\n\n"
        }
        userPrompt += "RECENT EXCHANGES:\n"
        // Include the most recent 10 messages, with markup stripped from
        // assistant turns so the digest model sees clean prose.
        let trimmed = recentExchanges.suffix(10)
        for msg in trimmed {
            let role = msg.role == "user" ? firstName : "You"
            let cleanedContent = msg.content.replacingOccurrences(
                of: #"\[/?[A-Z]+(?:\s+[^\]]*)?\]"#,
                with: " ",
                options: .regularExpression
            )
            let snippet = cleanedContent
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            userPrompt += "\n\(role): \(String(snippet.prefix(500)))"
        }
        userPrompt += "\n\nUpdated digest:"

        do {
            let result = try await utilityCompletion(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                temperature: 0.4
            )
            // Sanity bounds — never let the digest grow unbounded.
            let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, cleaned.count >= 20, cleaned.count <= 800 else {
                return currentDigest
            }
            return cleaned
        } catch {
            #if DEBUG
            print("[AIService] Memory digest refresh failed: \(error)")
            #endif
            return currentDigest
        }
    }

    /// Builds the system-prompt fragment that injects the user's long-term
    /// memory digest AND pinned facts. Pinned facts are first-class facts the
    /// user has explicitly told you to remember; the digest is the rolling
    /// natural-language summary refined over time. Returns nil if there's
    /// neither (e.g. brand-new install).
    static func buildMemoryDigestContext(
        digest: String?,
        pinnedFacts: [String],
        name: String
    ) -> String? {
        let hasDigest = digest.map { !$0.isEmpty } ?? false
        let hasFacts = !pinnedFacts.isEmpty
        guard hasDigest || hasFacts else { return nil }

        var sections: [String] = []
        sections.append("WHAT YOU KNOW ABOUT \(name.uppercased()) (long-term memory — refine your responses against this):")

        if hasFacts {
            // Pinned facts are FIRST because they're load-bearing — names of
            // family, life events, ongoing situations the user trusts you to
            // never forget. Treat as ground truth.
            sections.append("")
            sections.append("Pinned facts (the user explicitly told you these — never forget, never contradict):")
            for fact in pinnedFacts {
                sections.append("• \(fact)")
            }
        }

        if hasDigest, let digest {
            sections.append("")
            sections.append("Rolling digest (your evolving sense of \(name) from past conversations):")
            sections.append(digest)
        }

        sections.append("")
        sections.append("""
        Use this memory naturally. Reference it when it adds warmth or specificity. \
        Don't recite it back. Don't open with "I remember you mentioned…". Just let it \
        inform the way you teach, comfort, and pray. \
        If \(name) shares a NEW fact worth keeping forever (a name, a loss, a diagnosis, \
        an ongoing struggle), call the remember_fact tool — don't just hope the digest catches it.
        """)

        return sections.joined(separator: "\n")
    }
}

// MARK: - Pre-Conversation Briefing
//
// Phase 3B + 3D combined: a small "today + recent threads" snapshot the AI
// can naturally weave into responses. Distinct from the long-term memory
// digest (which is semantic — "what I know about you") in that this is a
// fresh, literal snapshot of what the user is doing RIGHT NOW: today's
// reading, current plan day, last-opened passage, and the last few
// conversation titles. Together they give the agent both the long arc and
// the immediate present.

extension AIService {

    /// Builds a compact briefing block to inject into the system prompt for
    /// the next chat call. Returns nil if there's nothing meaningful to share
    /// (very new install with no plans, no Bible activity, no prior chats).
    ///
    /// `currentConversationId` is excluded from the recent-threads list so the
    /// AI doesn't see the conversation it's currently inside as "previous".
    @MainActor
    static func buildPreConversationBriefing(
        profile: UserProfile,
        modelContext: ModelContext,
        currentConversationId: UUID,
        name: String
    ) -> String? {
        var lines: [String] = []

        // 1. Date + time of day — gives the AI calendar/season awareness
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        let dateString = dateFormatter.string(from: now)

        let hour = Calendar.current.component(.hour, from: now)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<22: timeOfDay = "evening"
        default: timeOfDay = "night"
        }
        lines.append("Today is \(dateString) (\(timeOfDay)).")

        // 2. Streak — only if it's meaningful
        if profile.streakCount >= 3 {
            lines.append("\(name) has a \(profile.streakCount)-day reading streak going.")
        }

        // 3. Last-read Bible passage — useful continuity
        if !profile.lastReadBookID.isEmpty,
           let book = BibleData.book(id: profile.lastReadBookID) {
            lines.append("Last opened in the Bible: \(book.name) \(profile.lastReadChapter).")
        }

        // 4. Active reading plan progress
        let progressDescriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.isActive == true && $0.completedDate == nil }
        )
        if let progress = (try? modelContext.fetch(progressDescriptor))?.first {
            let planID = progress.planID
            let planDescriptor = FetchDescriptor<ReadingPlan>(
                predicate: #Predicate { $0.id == planID }
            )
            if let plan = (try? modelContext.fetch(planDescriptor))?.first {
                let nextDay = progress.nextDay(totalDays: plan.totalDays)
                lines.append("Active reading plan: \(plan.name) — on day \(nextDay) of \(plan.totalDays).")
            }
        }

        // 5. Recent conversation threads (excluding the current one)
        var convDescriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        convDescriptor.fetchLimit = 6
        let recentConversations = (try? modelContext.fetch(convDescriptor)) ?? []
        let otherTitles = recentConversations
            .filter { $0.id != currentConversationId }
            .map(\.title)
            .filter { $0 != "New Conversation" }
            .prefix(3)
        if !otherTitles.isEmpty {
            let joined = otherTitles.map { "\"\($0)\"" }.joined(separator: ", ")
            lines.append("Recent conversation threads: \(joined).")
        }

        // Bail if we genuinely have nothing useful (only the date line)
        guard lines.count > 1 else { return nil }

        let body = lines.joined(separator: "\n")
        return """
        TODAY & RECENT CONTEXT (use naturally, don't recite back):
        \(body)

        If something here is relevant to what \(name) is asking, you can reference \
        it warmly — "given where you are in Romans 8 today" or "this connects to what \
        we explored about anxiety last week" — but never list this context out loud or \
        open the response with "I see you...".
        """
    }
}
