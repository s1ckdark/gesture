import AVFoundation
import Speech
import Combine

/// Listens for a wake word via on-device speech recognition. When detected,
/// opens a `gateSeconds`-long window during which gestures are allowed to fire.
/// Outside the window, gestures are suppressed (when voice gating is enabled).
@MainActor
final class VoiceTrigger: ObservableObject {
    @Published var isListening = false
    @Published var gateOpenUntil: Date?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var triggerWord: String = "gesture"
    let gateSeconds: TimeInterval = 5

    var isGateOpen: Bool {
        guard let until = gateOpenUntil else { return false }
        return Date() < until
    }

    func start(completion: ((Result<Void, Error>) -> Void)? = nil) {
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            DispatchQueue.main.async {
                guard let self else { return }
                guard auth == .authorized else {
                    completion?(.failure(NSError(domain: "VoiceTrigger", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Speech permission denied"])))
                    return
                }
                do {
                    try self.startEngine()
                    self.isListening = true
                    completion?(.success(()))
                } catch {
                    completion?(.failure(error))
                }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    private func startEngine() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "VoiceTrigger", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"])
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw NSError(domain: "VoiceTrigger", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"])
        }
        recognitionRequest.shouldReportPartialResults = true

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let phrase = result.bestTranscription.formattedString.lowercased()
                if phrase.contains(self.triggerWord.lowercased()) {
                    DispatchQueue.main.async {
                        self.gateOpenUntil = Date().addingTimeInterval(self.gateSeconds)
                    }
                    // Reset the recognition session so the same wake word can fire again
                    DispatchQueue.main.async { [weak self] in
                        self?.restart()
                    }
                }
            }
            if error != nil {
                DispatchQueue.main.async { [weak self] in self?.stop() }
            }
        }
    }

    private func restart() {
        guard isListening else { return }
        stop()
        try? startEngine()
        isListening = true
    }
}
