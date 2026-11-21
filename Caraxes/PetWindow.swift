import AppKit

@MainActor
final class PetWindow: NSPanel {
    private let animator: SpriteAnimator
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var hoverTimer: Timer?
    private var state: PetState = .sleep

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        let size = NSSize(width: 184, height: 140)
        let area = NSScreen.main?.visibleFrame ?? NSRect(origin: .zero, size: size)
        let frame = NSRect(x: max(area.minX, area.maxX - size.width - 24),
                           y: area.minY + 12, width: size.width, height: size.height)
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        guard let sprite = NSImage(named: NSImage.Name("Caraxes")),
              let image = sprite.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            preconditionFailure("The Caraxes image asset is missing.")
        }
        animator = SpriteAnimator(in: view, image: image,
                                  frame: CGRect(x: 12, y: 7, width: 160, height: 120))

        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        contentView = view
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
    }

    func showPet(state: PetState) {
        let movement: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged,
                                               .rightMouseDragged, .otherMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: movement) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePointer() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: movement) { [weak self] event in
            MainActor.assumeIsolated { self?.updatePointer() }
            return event
        }
        orderFrontRegardless()
        display(state)
    }

    func display(_ state: PetState) {
        self.state = state
        animator.display(state)
        updatePointer()
    }

    func stopMonitoringPointer() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    private func updatePointer() {
        let point = convertPoint(fromScreen: NSEvent.mouseLocation)
        let nearSprite = animator.movementBounds.contains(point)
        let shouldIgnore = !nearSprite || !animator.containsVisiblePixel(at: point)
        if ignoresMouseEvents != shouldIgnore {
            ignoresMouseEvents = shouldIgnore
        }

        // Recheck a stationary cursor only when the animated sprite can move beneath it.
        guard nearSprite, state == .idle else {
            hoverTimer?.invalidate()
            hoverTimer = nil
            return
        }
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePointer() }
        }
        hoverTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
