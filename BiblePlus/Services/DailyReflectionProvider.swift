import Foundation

enum DailyReflectionProvider {
    static func prompt(for profile: UserProfile) -> String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let burden = profile.currentBurdens.first ?? .none

        let prompts: [Burden: [String]] = [
            .anxiety: [
                "What\u{2019}s weighing on your heart that you can surrender to God today?",
                "Where do you need God\u{2019}s peace to replace your worry right now?",
                "What scripture has calmed your spirit in anxious moments?",
                "Write a prayer releasing one thing you cannot control today.",
                "How has God shown up for you in a past season of worry?",
                "What would it look like to fully trust God with your biggest concern?",
                "Name three things you\u{2019}re anxious about \u{2014} then write a prayer for each."
            ],
            .grief: [
                "What beautiful memory brings you comfort in this season of loss?",
                "How do you feel God\u{2019}s presence in your grief today?",
                "Write a letter to God about what you miss most.",
                "What has grief taught you about the depth of love?",
                "Where have you seen unexpected grace in your mourning?",
                "What promise of God speaks to your hurting heart today?",
                "How can you honor what you\u{2019}ve lost while embracing hope?"
            ],
            .doubt: [
                "What strengthened your faith in a moment you didn\u{2019}t expect?",
                "Where have you seen God\u{2019}s fingerprints recently, even faintly?",
                "What question would you ask God if He were sitting beside you?",
                "Write about a time God answered when you weren\u{2019}t sure He was listening.",
                "What does faith look like for you when certainty fades?",
                "Which story in scripture mirrors your struggle right now?",
                "What small step of trust can you take today?"
            ],
            .loneliness: [
                "Who is God placing on your heart to reach out to today?",
                "How has God been a companion in your quiet moments?",
                "Write about a time you felt deeply seen and known.",
                "What does God\u{2019}s promise \u{201C}I will never leave you\u{201D} mean to you today?",
                "How can you be a source of connection for someone else this week?",
                "What does your ideal community of faith look like?",
                "Where have you found unexpected belonging recently?"
            ],
            .anger: [
                "Where are you seeking peace in the midst of frustration?",
                "What injustice is stirring your heart \u{2014} and what can you do about it?",
                "Write a prayer asking God to soften a place of hardness in your heart.",
                "How can you practice forgiveness as an act of freedom today?",
                "What would it look like to respond with grace instead of anger?",
                "Where do you need God\u{2019}s patience to become your patience?",
                "What righteous cause is your anger pointing you toward?"
            ],
            .temptation: [
                "What gives you strength to choose God\u{2019}s way right now?",
                "Write about a time you overcame something you thought you couldn\u{2019}t.",
                "What scripture can be your shield today?",
                "Who in your life helps you stay accountable and grounded?",
                "What does victory look like for you in this season?",
                "How can you fill the space that temptation tries to occupy?",
                "Write a declaration of who God says you are."
            ],
            .health: [
                "How are you honoring the body God gave you today?",
                "Write a prayer of gratitude for your body \u{2014} even in its struggle.",
                "Where do you need God\u{2019}s healing touch most right now?",
                "What small act of care can you offer yourself today?",
                "How has this health journey deepened your dependence on God?",
                "What does trusting God with your health look like practically?",
                "Who can you ask to pray alongside you for healing?"
            ],
            .financial: [
                "Where are you trusting God as your provider today?",
                "Write about a time God provided in a way you didn\u{2019}t expect.",
                "What does contentment look like in your current season?",
                "How can you practice generosity even in a season of lack?",
                "What is God teaching you through this financial challenge?",
                "Write a prayer surrendering your financial worries to God.",
                "Where have you seen God\u{2019}s abundance in non-material ways?"
            ],
            .relationship: [
                "Who is God calling you to love more deeply today?",
                "Write a prayer for a relationship that needs healing.",
                "How can you reflect Christ\u{2019}s love in your closest relationships?",
                "What conversation have you been avoiding that God is nudging you toward?",
                "Where do you need more grace \u{2014} to give or to receive?",
                "How has a relationship shaped your understanding of God\u{2019}s love?",
                "Write about the kind of friend, partner, or family member you want to become."
            ],
            .purpose: [
                "What felt meaningful and God-honoring to you today?",
                "If God whispered your purpose, what do you think He\u{2019}d say?",
                "What gifts has God given you that the world needs right now?",
                "Write about a moment when you felt fully alive and aligned.",
                "Where do your passions and the world\u{2019}s needs intersect?",
                "What would you do for God\u{2019}s kingdom if fear weren\u{2019}t a factor?",
                "How is God preparing you through this season of searching?"
            ],
            .none: [
                "What are you most grateful for in this season of life?",
                "How did you see God move in your life this week?",
                "Write a prayer of thanks for three blessings you often overlook.",
                "What is God teaching you right now through everyday moments?",
                "Who has been an unexpected blessing in your life recently?",
                "What does your relationship with God look like today compared to a year ago?",
                "If you could ask God one thing today, what would it be?"
            ]
        ]

        let pool = prompts[burden] ?? prompts[.none]!
        return pool[dayOfYear % pool.count]
    }
}
