import SwiftUI
import GoogleSignIn

@main
struct PlanoteApp: App {
    init() {
        // 起動時に既存サインイン状態を復元（Google）
        // Microsoft (MSAL) は MicrosoftCalendarService の init で同期復元
        GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in
            // 復元完了を通知して UI を更新
            NotificationCenter.default.post(name: .googleSignInRestored, object: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // MSAL → GoogleSignIn の順で URL を処理する
                    if MicrosoftCalendarService.handleURL(url) { return }
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

extension Notification.Name {
    static let googleSignInRestored = Notification.Name("googleSignInRestored")
}
