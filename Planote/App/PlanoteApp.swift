import SwiftUI
import GoogleSignIn

@main
struct PlanoteApp: App {
    init() {
        // 起動時に既存サインイン状態を復元
        GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // GoogleSignIn のリダイレクト URL を処理
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
