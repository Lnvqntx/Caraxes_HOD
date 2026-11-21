import Foundation

enum PetState: Equatable {
    case sleep
    case idle
    case fly
    case perch
    case fire
}

@MainActor
final class PetStateMachine {
    static let flightDuration: TimeInterval = 2.4
    static let perchFlightDuration: TimeInterval = 0.9
    static let fireDuration: TimeInterval = 1.5

    private(set) var state: PetState = .idle
    private(set) var isPerched = false
    private(set) var target: WindowTracker.Target?
    private var transitionTimer: Timer?
    private var transitionGeneration = 0
    var onChange: ((PetState) -> Void)?
    var onPerchMove: (() -> Void)?
    var onRescan: (() -> Void)?

    func start() {
        scheduleTransition()
    }

    func stop() {
        transitionGeneration += 1
        transitionTimer?.invalidate()
        transitionTimer = nil
    }

    func updateTarget(_ next: WindowTracker.Target?) {
        let previous = target
        guard previous != next else { return }
        target = next

        if previous?.id == next?.id {
            if isPerched { onPerchMove?() }
        } else {
            isPerched = false
            transition(to: next == nil ? .idle : .fly)
        }
    }

    func handleClick() {
        switch state {
        case .sleep:
            transition(to: target == nil ? .idle : .perch)
        case .idle, .fly, .perch:
            transition(to: .fire)
        case .fire:
            break
        }
    }

    private func transition(to nextState: PetState) {
        stop()
        if nextState == .perch { isPerched = true }
        state = nextState
        onChange?(state)
        scheduleTransition()
    }

    private func scheduleTransition() {
        let delay: TimeInterval
        switch state {
        case .sleep: delay = .random(in: 30...120)
        case .idle, .perch: delay = .random(in: 5...15)
        case .fly: delay = target == nil ? Self.flightDuration : Self.perchFlightDuration
        case .fire: delay = Self.fireDuration
        }

        let generation = transitionGeneration
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance(generation: generation) }
        }
        transitionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func advance(generation: Int) {
        guard generation == transitionGeneration else { return }
        // Discover windows while roaming and revalidate the destination before landing.
        if state != .perch { onRescan?() }
        guard generation == transitionGeneration else { return }

        switch state {
        case .sleep: transition(to: isPerched ? .perch : .idle)
        case .fire:
            transition(to: isPerched ? .perch : (target == nil ? .idle : .fly))
        case .idle: transition(to: .fly)
        case .fly: transition(to: target == nil ? .sleep : .perch)
        case .perch: transition(to: .sleep)
        }
    }
}
