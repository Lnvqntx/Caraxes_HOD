import AppKit
import CoreGraphics

@MainActor
final class WindowTracker {
    struct Target: Equatable {
        let id: CGWindowID
        let bounds: CGRect
        let visibleScreen: CGRect
    }

    private let workspace = NSWorkspace.shared
    private var workspaceObservers: [NSObjectProtocol] = []
    private var screensObserver: NSObjectProtocol?
    private var pollTimer: Timer?
    private var pollInterval: TimeInterval?
    var onRefresh: ((Target?) -> Void)?

    func start() {
        let notifications = [NSWorkspace.didActivateApplicationNotification,
                             NSWorkspace.activeSpaceDidChangeNotification]
        workspaceObservers = notifications.map { name in
            workspace.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        screensObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func stop() {
        configurePolling(perched: false, sleeping: false)
        for observer in workspaceObservers {
            workspace.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        if let screensObserver {
            NotificationCenter.default.removeObserver(screensObserver)
            self.screensObserver = nil
        }
    }

    func configurePolling(perched: Bool, sleeping: Bool) {
        let interval: TimeInterval? = perched ? (sleeping ? 1 : 0.25) : nil
        guard interval != pollInterval else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        pollInterval = interval
        guard let interval else { return }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = interval / 10
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func refresh() {
        onRefresh?(frontmostWindow())
    }

    private func frontmostWindow() -> Target? {
        let screens = NSScreen.screens
        guard let primary = screens.first,
              let app = workspace.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.bundleIdentifier != "com.apple.dock",
              app.bundleIdentifier != "com.apple.SystemUIServer",
              app.bundleIdentifier != "com.apple.controlcenter",
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Quartz returns front-to-back order. Use only identity metadata and window geometry.
        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == app.processIdentifier,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let number = window[kCGWindowNumber as String] as? NSNumber,
                  let dictionary = window[kCGWindowBounds as String] as? [String: Any],
                  let quartz = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                  quartz.width >= 300, quartz.height > 0 else { continue }

            // Both coordinate systems use the primary display as their origin reference.
            // Flip once around its top edge, including windows on vertically offset displays.
            let bounds = CGRect(x: quartz.minX, y: primary.frame.maxY - quartz.maxY,
                                width: quartz.width, height: quartz.height)
            if screens.contains(where: { Self.matchesDisplay(bounds, $0.frame) }) {
                return nil
            }

            // Prefer the display containing the largest portion of the window's top edge.
            let topEdge = CGRect(x: bounds.minX, y: bounds.maxY - 1, width: bounds.width, height: 1)
            let screen = screens.max { first, second in
                let firstEdge = Self.overlap(topEdge, first.frame)
                let secondEdge = Self.overlap(topEdge, second.frame)
                if firstEdge != secondEdge { return firstEdge < secondEdge }
                return Self.overlap(bounds, first.frame) < Self.overlap(bounds, second.frame)
            }
            guard let screen, Self.overlap(bounds, screen.visibleFrame) > 0 else { continue }
            return Target(id: number.uint32Value, bounds: bounds, visibleScreen: screen.visibleFrame)
        }
        return nil
    }

    private static func matchesDisplay(_ bounds: CGRect, _ display: CGRect) -> Bool {
        abs(bounds.minX - display.minX) <= 2 && abs(bounds.maxX - display.maxX) <= 2 &&
        abs(bounds.minY - display.minY) <= 2 && abs(bounds.maxY - display.maxY) <= 2
    }

    private static func overlap(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    static func perchOrigin(for target: Target, sprite: CGRect) -> CGPoint {
        let screen = target.visibleScreen
        let window = target.bounds
        let left = max(window.minX, screen.minX)
        let right = min(window.maxX, screen.maxX)
        let top = min(window.maxY, screen.maxY)
        let fitsAbove = window.maxY + sprite.height + 6 <= screen.maxY
        let preferredX = fitsAbove ? right - max(90, sprite.width / 2) - sprite.width / 2
                                   : right - 12 - sprite.width
        let x = min(max(preferredX, left), max(screen.minX, screen.maxX - sprite.width))
        let y = fitsAbove ? top : top - 12 - sprite.height - 6
        return CGPoint(x: x - sprite.minX, y: max(screen.minY, y) - sprite.minY)
    }
}
