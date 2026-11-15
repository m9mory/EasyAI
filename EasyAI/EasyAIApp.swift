import SwiftUI

@main
struct EasyAIApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .preferredColorScheme(nil)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: ChatStore

    @State private var showKeyGate = false
    @State private var didShowKeyGate = false

    var body: some View {
        Group {
            if showKeyGate {
                ApiKeyView(mode: .onboarding) { showKeyGate = false }
            } else {
                ChatListView()
            }
        }
        .onAppear {
            guard !didShowKeyGate else { return }
            didShowKeyGate = true
            showKeyGate = !settings.hasKey
        }
    }
}
