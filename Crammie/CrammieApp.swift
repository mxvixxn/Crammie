import SwiftData
import SwiftUI

@main
struct CrammieApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(for: Textbook.self)
    }
}
