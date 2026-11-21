import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var petWindow: PetWindow?
    private let pet = PetStateMachine()
    private let tracker = WindowTracker()

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
        window.onClick = { [weak pet = self.pet] in pet?.handleClick() }
        pet.onChange = { [weak self] state in
            guard let self else { return }
            petWindow?.display(state, target: pet.target, perched: pet.isPerched)
            tracker.configurePolling(perched: pet.isPerched, sleeping: state == .sleep)
        }
        pet.onPerchMove = { [weak self] in
            guard let self, let target = pet.target else { return }
            petWindow?.follow(target)
        }
        pet.onRescan = { [weak tracker = self.tracker] in tracker?.refresh() }
        tracker.onRefresh = { [weak pet = self.pet] target in pet?.updateTarget(target) }
        window.showPet(state: pet.state)
        pet.start()
        tracker.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker.stop()
        pet.stop()
        petWindow?.stopMonitoringPointer()
    }
}
