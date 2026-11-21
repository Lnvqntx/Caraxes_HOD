enum PetState: Equatable {
    case sleep
    case idle
    case fly
    case perch
    case fire
}

@MainActor
final class PetStateMachine {
    private(set) var state: PetState = .idle
    var onChange: ((PetState) -> Void)?

    func transition(to nextState: PetState) {
        guard state != nextState else { return }
        state = nextState
        onChange?(state)
    }
}
