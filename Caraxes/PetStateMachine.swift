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
    nonisolated static let flightDuration: TimeInterval = 2.4
    static let fireDuration: TimeInterval = 1.5

    private(set) var state: PetState = .idle
    private var transitionTimer: Timer?
    var onChange: ((PetState) -> Void)?

    func start() {
        scheduleTransition()
    }

    func stop() {
        transitionTimer?.invalidate()
        transitionTimer = nil
    }

    func handleClick() {
        switch state {
        case .sleep:
            transition(to: .idle)
        case .idle, .fly, .perch:
            transition(to: .fire)
        case .fire:
            break
        }
    }

    private func transition(to nextState: PetState) {
        stop()
        state = nextState
        onChange?(state)
        scheduleTransition()
    }

    private func scheduleTransition() {
        let delay: TimeInterval
        let nextState: PetState
        switch state {
        case .sleep:
            delay = .random(in: 30...120)
            nextState = .idle
        case .idle:
            delay = .random(in: 5...15)
            nextState = .fly
        case .fly:
            delay = Self.flightDuration
            nextState = .sleep
        case .fire:
            delay = Self.fireDuration
            nextState = .idle
        case .perch:
            return
        }

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.transition(to: nextState) }
        }
        transitionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
