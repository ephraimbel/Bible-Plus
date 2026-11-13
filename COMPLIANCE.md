# Bible+ licensing & App Store compliance

Audit date: 2026-11-13. This file records what was changed in code, and what
**still has to be done by hand** (App Store Connect, Supabase, assets).

---

## 1. Bible text licensing (lawsuit risk)

### What was wrong
| Problem | Why it's a legal risk |
|---|---|
| NIV, ESV, NLT, NASB, MSG, NKJV streamed from **bolls.life** | These are copyrighted by Biblica, Crossway, Tyndale, Lockman, NavPress and Thomas Nelson. Bible+ had no license, and sold access to them behind Pro ("Every Bible translation — all 8"). bolls.life having the text doesn't give us any rights. |
| AI prompt said *"Quote from the NIV/ESV/…"* | The model reproduced copyrighted translations from memory, in a paid product. |
| helloao catalog shown unfiltered | helloao's *code* is MIT, but each translation has its own license. Of 1,505 translations, **777 are CC BY-NC (non-commercial)** and **89 are CC BY-ND (no derivatives)**. A paid app is commercial use, and the AI excerpts and paraphrases text (derivatives). |
| Language defaults `ind_ayt` (CC BY-NC), `pol_ubg` (CC BY-ND), `amh_amh` (no license info) | These are shown to every Indonesian, Polish and Amharic user by default. |
| AI told to use "that language's major Bible translation" | That means RVR1960, NVI, Luther 2017 and similar, which are all copyrighted. |

### What the code does now
- **No Bible API at all.** bolls.life and bible.helloao.org are both gone from the app. Every translation is **built into the app** (`Resources/Bible/`, generated once by `scripts/bundle_bibles.py`), so there are no Bible-API terms of service to follow or break, and reading works offline. helloao's static files were used once as a download source; what governs use is each text's own license (public domain / CC), not helloao.
- **One policy** (`Shared/Services/TranslationLicensePolicy.swift`): a translation is allowed only if it is public domain, or its license allows **both commercial use and derivatives**. Unknown licenses are denied.
- **bolls.life removed entirely.** NIV/ESV/etc. can't be selected, fetched, searched, compared or quoted. The enum cases remain only so old saved data still loads. `BibleTranslation.licensed` maps them to WEB.
- **Launch migration** (`LicenseCompliance.swift`): moves NIV/ESV users to WEB and clears restricted helloao picks. It also **deletes cached copyrighted text** from devices.
- **Translations offered (17 bundled + KJV/WEB):**
  - English, public domain: BSB (Berean Standard Bible, a modern NIV/ESV-style translation; public domain since 30 April 2023), ASV, YLT, Douay-Rheims, KJV and WEB.
  - Other languages, public domain: Spanish RV1909, French LSG, German Luther 1912, Italian Riveduta, Russian Synodal, Chinese CUV (simplified and traditional), Korean 1910, Japanese Kougo-yaku.
  - Other languages, CC BY/BY-SA (credited in the reader): Portuguese Bíblia Livre, Indonesian TSI, Tagalog ULB, Swahili ULB.
  - We deliberately avoid Biblica's "open" editions. Polish and Amharic fall back to English because no suitable open text exists.
- **Attribution** line shown under chapters for CC BY-SA translations (Portuguese, Polish, Indonesian, Tagalog, Swahili defaults).
- **KJV**: shows the customary UK Crown-rights notice. **WEB**: text is used unmodified (the name "World English Bible" is an eBible.org trademark and must not be put on altered text).
- **AI**: must quote Scripture **word-for-word** and label paraphrases as its own words. This keeps us inside the WEB trademark rule and the CC BY-SA ShareAlike terms. The client prompt and a **server-side policy** (`supabase/functions/chat/index.ts`) forbid quoting copyrighted translations. The Compare card only accepts KJV/WEB/BSB/ASV/YLT/DRA.
- Search runs offline over the bundled public-domain text.

### Still to do
- **Deploy the edge function**: `supabase functions deploy chat`.
- Users' existing *saved verses / highlights* may contain NIV/ESV text they saved earlier. That is the user's own data on their device, and we left it alone.
- If you ever want NIV/ESV/NLT back, license them properly through **API.Bible** (American Bible Society) or the publishers directly. Read the AI clauses: API.Bible forbids using its content to train or fine-tune AI without written consent, and Biblica forbids derivative works.

---

### Terms of service checked
| Service | Requirement | Status |
|---|---|---|
| OpenAI API | Disclose that AI voices are AI-generated | Shown in the voice picker and the Terms |
| OpenAI API | Minors may use it only with parental consent; extra safeguards for under-18s | The consent screen requires confirming 18+ or parental permission; crisis safety rules are in place |
| OpenAI API | No impersonation without disclosure | Biblical-figure chats are labelled as an AI portrayal (server policy and Terms) |
| BSB, KJV, WEB, ASV, YLT, DRA and the other public-domain texts | None (public domain); KJV has a UK Crown notice; WEB name only on unmodified text | Done |
| CC BY / BY-SA texts | Attribution, license link, ShareAlike for adaptations | Credit line in the reader; AI quotes verbatim |
| TikTok Business SDK | IDFA and cross-app tracking only with ATT | The SDK is not started without ATT |
| RevenueCat / TelemetryDeck | Disclose in the privacy policy | Disclosed |

## 2. App Store Review fixes made in code

| Guideline | Fix |
|---|---|
| 5.6.1 Reviews | **Removed the review step from onboarding.** Removed the custom "Enjoying Bible+?" pre-prompt (review gating). The review prompt is no longer shown mid-chat after the first message. Only Apple's native prompt is used now: after 3 or more days of use, at most once every 120 days. Settings › Rate the App opens the App Store write-review page. |
| 5.1.2(i) AI data sharing | **Explicit consent screen (also confirms 18+ or parental permission) before any data goes to OpenAI.** It names the provider and lists exactly what is sent. All AI network calls are blocked until consent is given, and consent can be withdrawn in Settings › AI & Privacy. Fixed the misleading onboarding line "This stays between us". |
| 5.1.1 / 1.4.1 AI safety | Crisis instructions (988 / local emergency numbers) added to the client prompt **and** enforced on the server, with crisis keyword detection. The chat now always shows the line "AI can make mistakes. Not a substitute for a pastor, counselor, or doctor." Long-press › **Report Response** on AI messages. |
| 5.1.2 Tracking / ATT | The TikTok SDK now **starts only after the user allows tracking**, and all events are dropped before that. |
| Privacy manifest | `NSPrivacyTracking=true`. Collected data types are declared (name, sensitive info, user content, product interaction, purchase history, device ID). Added the app-group UserDefaults reason `1C8F.1` and a widget-extension manifest. |
| 2.1 Crash | Added `NSPhotoLibraryAddUsageDescription`, which the "Save Image" share action needs. Corrected the microphone purpose string, which falsely said audio is processed on-device. |
| 3.1.1 Restore | Restore now gives feedback. On the hard onboarding paywall, a successful restore moves the user forward instead of leaving them stuck. |
| 3.1.2 Subscriptions | "Free trial" copy is shown only to eligible users, with the trial length read from the product. Added the full auto-renewal disclosure. Links are labelled "Terms of Use (EULA)" and "Privacy Policy". |
| 2.3.1 Accuracy | Removed "Unlimited AI companion" (Pro is capped at 200 a day), the "Every Bible translation — all 8" claim, and the "92% of members… 2026 member survey" stat. Voices are labelled AI-generated. |
| 3.1.2 Paywall | The onboarding paywall now has a visible "Continue with the free version" link, since a free tier exists. |
| IP | Removed the "Christ the Redeemer" image and video, which were sold as Pro backgrounds without a license. |
| Website | `privacy.html`, `terms.html` and `support.html` were rewritten to match reality: OpenAI, TikTok, TelemetryDeck and RevenueCat are disclosed, the false "no analytics" claim is gone, prices, plans and quotas are correct, the Apple EULA is linked, and the translation FAQ is fixed. **Redeploy the website.** |

---

## 3. Manual steps before the next submission

1. **App Store Connect › App Privacy label**: update it to match `PrivacyInfo.xcprivacy`:
   - Name, Sensitive Info and Other User Content: App Functionality, not linked, not tracking.
   - Product Interaction: Analytics.
   - Purchase History and Device ID: **Tracking** (TikTok, with ATT).
2. **Age rating questionnaire**: answer the AI chatbot and unrestricted-content questions honestly. 13+ matches the Terms.
3. **Deploy** the `chat` Supabase function and the website. The Bible translations add about 73 MB of uncompressed JSON (a much smaller download after App Store compression).
4. **Keep a provenance record** (source and license) for the ~76 background videos and the sound files. (The "Christ the Redeemer" image and video were removed, because the Archdiocese of Rio licenses commercial use of the statue's image.)
5. **Rotate the Supabase anon key.** `Shared/Secrets.swift` was committed in git history (`483d4cd`, `a86b8fb`). The chat function enforces Free/Pro limits only on the client. Consider App Attest or a RevenueCat entitlement check on the server.
6. **Localization**: the new strings (consent screen, disclosures, attribution) are English-only until the String Catalog is re-translated (`scripts/translate_catalog.py`).
7. **Review notes for Apple**: mention that the AI asks for consent before sharing data, and that Restore works on the onboarding paywall.
8. Optional: `BPEarlyBootstrap.m` forces the app language to English on first launch, so system dialogs show in English on non-English devices. It isn't a guideline violation, and changing it affects the whole localization flow, so it was left as is.
