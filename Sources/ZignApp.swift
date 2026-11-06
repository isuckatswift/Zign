
import SwiftUI

@main
struct ZignApp: App {
    @State private var appTheme: ColorScheme? = .dark

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appTheme)
        }
    }
}
