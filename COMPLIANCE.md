# Bible+ 1.1.3 (36): licensing and release verification

Updated 2026-11-13. This is an engineering verification record, not a legal opinion or a guarantee of App Review approval.

## Scripture sources and AI

The app makes no runtime requests to a Bible API. It reads 18 bundled editions offline: WEB plus the 17 entries in `Resources/Bible`. This removes the former dependency on bolls.life and the unrestricted helloao catalog. Source downloads still require checking each text's own license; an API server's software license does not license its Bible texts.

| Editions | Recorded rights |
| --- | --- |
| WEB, BSB, ASV, YLT, Douay-Rheims | Public domain; preserve unmodified WEB wording when using its name |
| RV1909, Louis Segond, Luther 1912, Riveduta, Synodal, CUV simplified/traditional, Korean 1910, Japanese Kougo-yaku | Public domain according to the recorded edition sources |
| Portuguese Bíblia Livre | CC BY |
| Indonesian TSI, Tagalog ULB, Swahili ULB | CC BY-SA |

`Shared/Services/TranslationLicensePolicy.swift` is a deny-by-default allowlist. Unknown editions, Biblica editions and NC/ND licenses are not accepted. NIV, ESV, NLT, NASB, NKJV, MSG and CSB cannot be selected or downloaded. KJV was also removed because a notice alone does not resolve its UK Crown rights for worldwide commercial distribution. Legacy enum values remain decodable and migrate to WEB.

Source and license URLs, copyright notices and hashes are recorded in `Resources/Bible/licenses.json`. Principal sources include [WEB copyright](https://ebible.org/eng-web/copyright.htm), [BSB terms](https://berean.bible/terms.htm), the individual eBible edition pages and [helloao's download documentation](https://bible.helloao.org/docs/). Creative Commons attribution and license links accompany reader chapters, copied excerpts and shared verse images. Missing books fall back to WEB with an explicit banner and actual edition badge.

The 66-book WEB bundle was replaced with verified source wording. All 628 Bible feed entries across 16 content locales and all 308 daily-path passages resolve to verbatim public-domain text. Scripture was not machine-translated. Hash-based migration updates retired wording while retaining saved notes/highlights; cached restricted Bible downloads are removed.

AI remains available with permission. Client and mandatory server instructions prohibit restricted-edition quotations and require explanations/paraphrases to be identified as such. `VerifiedScripture` resolves Scripture, Verse and CrossRefs cards against local WEB, including persisted/copied card content, and drops unverifiable cards. Compare loads allowed bundled editions directly. Arbitrary model prose is not mechanically guaranteed to obey every instruction; response reporting remains available.

## Privacy, onboarding and subscriptions

- No onboarding review request, custom rating pre-prompt or mid-first-chat request. Later review prompts use Apple's native API, after at least three days and with a 120-day application cooldown.
- Explicit OpenAI consent covers chat messages, voice transcripts, first name, onboarding answers, AI memory, Bible text and narrator selection. Chat, utility calls, voice chat, Bible audio and voice previews all check permission. Settings can revoke it. The consent screen requires age 13+, with parental permission under 18.
- Crisis and age-appropriate content rules run on the server for every model tier. The app identifies AI and provides a limitation notice and Report Response action.
- TikTok starts and sends manual events only while ATT is authorized. Privacy manifests include the SDK tracking host, collected data types and UserDefaults reasons.
- Restore Purchases reports its result. The onboarding paywall offers the free version, renewal terms, Privacy Policy and Terms of Use links. Trial wording uses confirmed eligibility and the actual product period. Pro describes 200 daily messages and five narrator voices.
- Photos, microphone and speech purpose strings match the features. Native Apple speech recognition may use Apple servers; the policy discloses this.
- All 140 release disclosure/consent keys have translated entries in all 40 supported locales. Placeholder and protected-token checks pass. This does not claim that every historical app string is localized.

## Live services and costs

At the owner's direction, the two separately named functions `bibleplus-chat` and `bibleplus-tts` run on the existing Momentum Supabase project `hhhlrqngutmyccfpgdoq`. Existing Momentum functions and data were not replaced. Bible audio uses the private `bibleplus-tts-cache` bucket. Only these two routes disable gateway JWT verification; each handler validates its dedicated application admission token.

A dedicated Bible+ OpenAI key is stored in server secrets and the owner's Mac Keychain. It is not shipped in the app or committed. OpenAI optional data-sharing settings were confirmed disabled. No new hosting subscription was purchased. Supabase usage is shared with Momentum and OpenAI API usage still consumes the existing paid balance.

The former Bible+ Supabase project remains paused. Installed older app versions continue to point at it; the restored relay is available through this new build. No other project was paused. Do not rotate unrelated or legacy keys as part of this release.

The updated public website is published with Sites because Vercel rejected deployments for its team fair-use limit. Site ID: `appgprj_6af6bcb3a3d08191bf48c964129e2ff6`. Source is retained in the Sites repository and mirrored in `website/`. The custom-domain change awaits GoDaddy identity verification; final HTTPS verification is required before submission.

## Verification performed

- App and widget built and archived with Xcode 26.2, zero errors. Existing concurrency/deprecation warnings remain; this is not a zero-warning build.
- 22 tests across Compliance and AudioBibleWatchdog suites passed. Coverage includes allowlist rejection, all English editions loading Genesis 1/John 3 offline, all bundled editions loading John 3, source credits, Indonesian Psalms fallback to WEB, offline search, legacy selection/cache migration, quote-card sanitization, consent and audio watchdog behavior.
- Release archive audit: version 1.1.3/build 36, 18 permitted Bible files, no KJV, five valid app/extension/SDK privacy manifests. The widget contains shared WEB only; it excludes the 17 additional Bible bundles and migration hash map.
- Live relay: normal and streamed chat, crisis response, refusal of NIV requests, invalid admission token (401), malformed request (400), all five MP3 voices, invalid voice (400), and cache-hit behavior verified. Both Deno entrypoints type-check.
- Fresh simulator onboarding went directly to the paywall without a review request. Psalm 1:2 replaced the unsupported survey claim. Restore without a purchase displayed the result; free continuation worked; trial/renewal information displayed.
- First chat: Not Now retained the draft; permission allowed a real streamed answer. Revoking permission caused voice chat to ask again. Spanish, Arabic and Japanese consent screens were visually checked.
- WEB and BSB reader chapters loaded. A BSB verse image exported through the native share sheet, requested Photos permission and was saved successfully.
- Four new App Store screenshots from build 36 replaced obsolete quotation, testimonial and ranking claims; all four assets reached COMPLETE.
- Build 36 uploaded, processed as VALID/APP_STORE_ELIGIBLE and was attached to version 1.1.3. Non-exempt encryption is false. Release remains manual after approval.

## App Store configuration

Published privacy labels identify all seven collected types as linked to the user. Name and Sensitive Info: functionality/personalization, no tracking. Other User Content: functionality, no tracking. User ID: developer advertising/tracking. Device ID: developer advertising/analytics/tracking. Purchase History: functionality/developer advertising/tracking. Product Interaction: analytics/developer advertising/tracking. Tracking is conditional on ATT permission; labels disclose the possible collection.

The age questionnaire uses a 13+ override and disclosed relevant infrequent biblical themes. Version description, keywords, What's New and reviewer notes describe the actual editions, quotas, offline fallback, AI permission and restore behavior. Website legal pages identify OpenAI, Supabase, Apple speech, RevenueCat, TelemetryDeck and TikTok where applicable.

## Remaining verification limits and follow-up

- The currently shipped App Store binary cannot be installed on the simulator. Upgrade migration was tested with persisted legacy fixtures, not an App Store binary on a physical device.
- A sandbox Apple account with an already-consumed introductory trial was not available. Trial eligibility logic was checked in code/tests; an eligible offer and no-purchase restore were exercised manually.
- Background video/sound assets predate this migration. The repository does not contain a complete per-file provenance ledger. The identified Christ the Redeemer asset was removed; this release does not certify all historical asset rights. Retain or obtain original asset license records.
- Server Free/Pro entitlement enforcement and stronger app attestation remain a separate hardening change. The embedded admission token is extractable, and per-instance IP limits are not a durable user quota.
- Submission and custom-domain completion must be recorded after the final checks. Do not merge the PR without the owner's approval.
