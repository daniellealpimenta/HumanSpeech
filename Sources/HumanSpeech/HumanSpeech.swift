// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Speech
import AVFoundation
import Combine

// 1. ISOLAR A CLASSE NO MAIN ACTOR
// Isso garante que todo o acesso às propriedades da classe seja seguro para a UI.
@MainActor
public class AudioManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var soundSamples: [Float]
    @Published public var transcribedText: String = ""
    @Published public var isRecording: Bool = false
    
    // MARK: - Audio Properties
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Sample Handling Properties
    private let numberOfSamples: Int
    private var currentSample: Int = 0 // Tornada 'private' para melhor encapsulamento
    private var timer: Timer?

    public init(numberOfSamples: Int = 30) {
        self.numberOfSamples = numberOfSamples
        self.soundSamples = [Float](repeating: -50.0, count: numberOfSamples)
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    }

    public func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    public func startRecording() {
        guard !isRecording else { return }
        
        do {
            audioEngine = AVAudioEngine()
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = audioEngine!.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest?.shouldReportPartialResults = true
            
            // A closure do recognitionTask roda em uma thread de fundo.
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] (result, error) in
                // 2. VOLTAR PARA O MAIN ACTOR USANDO 'TASK'
                // Precisamos explicitamente voltar ao MainActor para atualizar as propriedades.
                Task {
                    guard let self = self else { return }
                    if let result = result {
                        self.transcribedText = result.bestTranscription.formattedString
                    } else if let error = error {
                        print("Recognition task error: \(error)")
                        self.stopRecording()
                    }
                }
            }
            
            // A closure do installTap roda em uma thread de áudio de alta prioridade.
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
                self?.recognitionRequest?.append(buffer)
                
                // 2. VOLTAR PARA O MAIN ACTOR USANDO 'TASK'
                // Da mesma forma, pulamos para o MainActor para fazer as atualizações.
                Task {
                    self?.updateAudioLevel(from: buffer)
                }
            }

            audioEngine?.prepare()
            try audioEngine?.start()
            
            self.isRecording = true
            
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
            stopRecording()
        }
    }

    public func stopRecording() {
        // ... o corpo desta função permanece o mesmo ...
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        try? AVAudioSession.sharedInstance().setActive(false)
        
        self.isRecording = false
    }

    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength))
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedPower = max(-50, avgPower)
        
        // 3. REMOVER O DISPATCHQUEUE.MAIN.ASYNC
        // Não é mais necessário, pois o método inteiro já está garantido de rodar no MainActor.
        self.soundSamples[self.currentSample] = normalizedPower
        self.currentSample = (self.currentSample + 1) % self.numberOfSamples
    }
}
