import Foundation
import AppTrackingTransparency
import TikTokBusinessSDK

@MainActor
final class TikTokAnalyticsService {
    static let shared = TikTokAnalyticsService()

    private var initialized = false

    private init() {}

    func initializeSDK() {
        guard !initialized else { return }
        guard Secrets.tikTokAppId != "REPLACE_WITH_TIKTOK_APP_ID" else {
            #if DEBUG
            print("[TikTok] SDK init skipped — tikTokAppId placeholder not set in Secrets.swift")
            #endif
            return
        }

        guard let config = TikTokConfig(
            accessToken: Secrets.tikTokAccessToken,
            appId: Secrets.tikTokAppStoreId,
            tiktokAppId: Secrets.tikTokAppId
        ) else {
            return
        }

        #if DEBUG
        config.enableDebugMode()
        #endif

        TikTokBusiness.initializeSdk(config) { success, error in
            #if DEBUG
            if let error {
                print("[TikTok] init error: \(error.localizedDescription)")
            } else {
                print("[TikTok] init success: \(success)")
            }
            #endif
        }

        initialized = true
    }

    func requestTrackingAuthorization() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        let status = await ATTrackingManager.requestTrackingAuthorization()
        #if DEBUG
        print("[TikTok] ATT status: \(status.rawValue)")
        #endif
    }

    func identify(userId: String) {
        TikTokBusiness.identify(
            withExternalID: userId,
            externalUserName: nil,
            phoneNumber: nil,
            email: nil
        )
    }

    func trackOnboardingComplete() {
        let event = TikTokBaseEvent(eventName: TTEventName.completeTutorial.rawValue)
        TikTokBusiness.trackTTEvent(event)
    }

    func trackTrialStarted() {
        let event = TikTokBaseEvent(eventName: TTEventName.startTrial.rawValue)
        TikTokBusiness.trackTTEvent(event)
    }

    func trackSubscribed() {
        let event = TikTokBaseEvent(eventName: TTEventName.subscribe.rawValue)
        TikTokBusiness.trackTTEvent(event)
    }

    func trackPurchase(productId: String, revenue: Decimal, currency: String = "USD") {
        let event = TikTokPurchaseEvent()
        event.setContentId(productId)
        event.setCurrency(TikTokAnalyticsService.currency(for: currency))
        event.setValue(NSDecimalNumber(decimal: revenue).stringValue)
        TikTokBusiness.trackTTEvent(event)
    }

    private static func currency(for code: String) -> TTCurrency {
        switch code.uppercased() {
        case "USD": return TTCurrency.USD
        case "EUR": return TTCurrency.EUR
        case "GBP": return TTCurrency.GBP
        case "CAD": return TTCurrency.CAD
        case "AUD": return TTCurrency.AUD
        default: return TTCurrency.USD
        }
    }
}
