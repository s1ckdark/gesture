import Foundation
import Combine

@MainActor
final class OnboardingModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome = 0
        case camera
        case accessibility
        case demo
        case done
    }

    @Published var step: Step = .welcome
    @Published var demoGestureSeen: String? = nil

    var totalSteps: Int { Step.allCases.count - 1 }  // exclude .done

    func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func reset() {
        step = .welcome
        demoGestureSeen = nil
    }

    func handleGesture(_ name: String) {
        guard step == .demo else { return }
        demoGestureSeen = name
    }
}
