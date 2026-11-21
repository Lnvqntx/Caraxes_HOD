import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var petWindow: PetWindow?
    private let pet = PetStateMachine()

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Caraxes"

        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit Caraxes", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        item.menu = menu
        statusItem = item

        let window = PetWindow()
        petWindow = window
        pet.onChange = { [weak window] state in
            window?.display(state)
        }
        window.showPet(state: pet.state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        petWindow?.stopMonitoringPointer()
    }
}
