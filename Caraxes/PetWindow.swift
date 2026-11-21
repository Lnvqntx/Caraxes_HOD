import AppKit
import QuartzCore

@MainActor
final class PetWindow: NSPanel {
    private struct Flight {
        let origin: CGPoint
        let destination: CGPoint
        let startedAt: CFTimeInterval
        let duration: TimeInterval

        var progress: CGFloat {
            min(1, CGFloat((CACurrentMediaTime() - startedAt) / duration))
        }
    }

    private let animator: SpriteAnimator
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var frameTimer: Timer?
    private var state: PetState = .sleep
    private var flight: Flight?
    var onClick: (() -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        let size = NSSize(width: 340, height: 340)
        let area = Self.mainScreenArea ?? NSRect(origin: .zero, size: size)
        let frame = NSRect(x: max(area.minX, area.maxX - size.width - 24),
                           y: area.minY + 12, width: size.width, height: size.height)
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        animator = SpriteAnimator(in: view)

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

    private static var mainScreenArea: CGRect? {
        // The primary display is first. NSScreen.main follows the focused window.
        NSScreen.screens.first?.visibleFrame
    }

    func showPet(state: PetState) {
        let movement: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged,
                                               .rightMouseDragged, .otherMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: movement) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.updatePointer() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: movement) { [weak self] event in
            DispatchQueue.main.async { [weak self] in self?.updatePointer() }
            return event
        }
        display(state)
        orderFrontRegardless()
        updatePointer()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown,
           animator.containsVisiblePixel(at: event.locationInWindow) {
            onClick?()
            return
        }
        super.sendEvent(event)
    }

    func display(_ state: PetState, target: WindowTracker.Target? = nil, perched: Bool = false) {
        if perched, let target {
            setFrameOrigin(perchOrigin(for: target, state: state))
        } else if let flight, state == .sleep {
            setFrameOrigin(flight.destination)
        }
        flight = nil
        self.state = state

        if state == .fly {
            let origin = frame.origin
            let destination = target.map { perchOrigin(for: $0, state: .perch) } ?? randomDestination()
            let duration = target == nil ? PetStateMachine.flightDuration : PetStateMachine.perchFlightDuration
            let dx = destination.x - origin.x
            let dy = destination.y - origin.y
            let slope = atan2(dy, max(abs(dx), 1))
            let tilt = min(0.17, max(-0.17, slope)) * (dx < 0 ? -1 : 1)
            flight = Flight(origin: origin, destination: destination,
                            startedAt: CACurrentMediaTime(), duration: duration)
            animator.display(state, facingLeft: dx < 0, tilt: tilt)
        } else {
            animator.display(state)
        }

        // Flush the state change before sampling the new presentation layers.
        CATransaction.flush()
        updatePointer(usePresentation: false)
    }

    func follow(_ target: WindowTracker.Target) {
        let origin = perchOrigin(for: target, state: state)
        guard origin != frame.origin else { return }
        setFrameOrigin(origin)
        updatePointer()
    }

    private func perchOrigin(for target: WindowTracker.Target, state: PetState) -> CGPoint {
        WindowTracker.perchOrigin(for: target, sprite: animator.perchFootprint(for: state))
    }

    func stopMonitoringPointer() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        frameTimer?.invalidate()
        frameTimer = nil
    }

    private func randomDestination() -> CGPoint {
        guard let area = Self.mainScreenArea else { return frame.origin }
        return CGPoint(
            x: .random(in: area.minX...max(area.minX, area.maxX - frame.width)),
            y: .random(in: area.minY...max(area.minY, area.maxY - frame.height))
        )
    }

    private func updatePointer(usePresentation: Bool = true) {
        let point = convertPoint(fromScreen: NSEvent.mouseLocation)
        let visible = animator.containsVisiblePixel(at: point, usePresentation: usePresentation)
        if ignoresMouseEvents == visible {
            ignoresMouseEvents = !visible
        }

        let needsFrames = state == .fly ||
            ((state == .idle || state == .perch) && animator.movementBounds.contains(point))
        guard needsFrames else {
            frameTimer?.invalidate()
            frameTimer = nil
            return
        }
        guard frameTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.advanceFrame() }
        }
        frameTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func advanceFrame() {
        if let flight {
            let t = flight.progress
            let eased = t * t * (3 - 2 * t)
            setFrameOrigin(CGPoint(
                x: flight.origin.x + (flight.destination.x - flight.origin.x) * eased,
                y: flight.origin.y + (flight.destination.y - flight.origin.y) * eased
            ))
        }
        updatePointer()
    }
}
