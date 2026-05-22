// Earliest-possible language lock. Runs via a C constructor function,
// which dyld executes when the binary is loaded — before @main, before
// any Swift code, and critically before iOS caches Bundle.main's
// preferred localizations.
//
// Why a C constructor and not an Objective-C `+load` method: the linker
// dead-strips Objective-C classes that are never referenced from Swift
// (no bridging header → no reference), so `+load` silently never fires.
// `__attribute__((constructor))` C functions are always preserved.
//
// Writing AppleLanguages in LocalizationService.bootstrap() (called from
// BiblePlusApp.init()) is too late: by then iOS has already resolved
// which .lproj to draw system dialogs from (notification permission,
// StoreKit sheets, App Store UI), so on a Spanish device those popups
// render in Spanish even though we lock our in-app UI to English.
//
// Policy:
//   • First launch ever → force AppleLanguages = ["en"]
//   • Relaunch with stored user pick → honor it (with sub-tag fallback)
//   • Relaunch on "follow system" → leave AppleLanguages untouched
//
// The UserDefaults keys mirror LocalizationService.swift constants. Keep
// these in sync if the Swift side ever renames them.

#import <Foundation/Foundation.h>

// `used` pins the symbol so the linker can't dead-strip the translation
// unit when nothing references it from Swift. `constructor` places it in
// the __mod_init_func section so dyld invokes it at load time. Without
// `used`, the linker was silently dropping the whole .o file and the
// first-launch language lock never ran.
__attribute__((used, constructor))
void BPEarlyLanguageLock(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL hasInit = [defaults boolForKey:@"io.bibleplus.languageInitialized"];

        if (!hasInit) {
            // First launch: lock everything (in-app UI + iOS-native dialogs)
            // to English. LocalizationService mirrors this write on its own
            // init so Swift state and UserDefaults stay consistent.
            [defaults setObject:@[@"en"] forKey:@"AppleLanguages"];
            return;
        }

        // Subsequent launches: replay whatever the user has chosen so iOS
        // native chrome matches our in-app language. "Follow system" is
        // stored as a missing key — leave AppleLanguages alone in that case.
        NSString *storedCode = [defaults stringForKey:@"io.bibleplus.selectedLanguageCode"];
        if (storedCode.length == 0) {
            return;
        }

        if ([storedCode containsString:@"-"]) {
            NSString *base = [[storedCode componentsSeparatedByString:@"-"] firstObject];
            if (base.length > 0 && ![base isEqualToString:storedCode]) {
                [defaults setObject:@[storedCode, base] forKey:@"AppleLanguages"];
                return;
            }
        }
        [defaults setObject:@[storedCode] forKey:@"AppleLanguages"];
    }
}
