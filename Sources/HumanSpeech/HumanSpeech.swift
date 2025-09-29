// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Speech
import AVFoundation
import Combine

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
    private var currentSample: Int = 0
    private var timer: Timer?

    public init(numberOfSamples: Int = 30) {
        self.numberOfSamples = numberOfSamples
        self.soundSamples = [Float](repeating: -50.0, count: numberOfSamples) // Inicializa com um valor baixo
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR")) // Use o local desejado
    }

    public func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    public func startRecording() {
        guard !isRecording else { return }
        
        // --- Setup Áudio ---
        do {
            audioEngine = AVAudioEngine()
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = audioEngine!.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // --- Setup Speech Recognition ---
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest?.shouldReportPartialResults = true
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] (result, error) in
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                    if result.isFinal {
                        // Se quiser parar automaticamente no final da fala, descomente as linhas abaixo
                        // self?.stopRecording()
                    }
                } else if let error = error {
                    print("Recognition task error: \(error)")
                    self?.stopRecording()
                }
            }
            
            // --- Instalar o "Tap" para monitorar o áudio ---
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
                // Envia o buffer para a transcrição
                self?.recognitionRequest?.append(buffer)
                
                // Calcula o nível de áudio para a visualização
                self?.updateAudioLevel(from: buffer)
            }

            // --- Iniciar o motor ---
            audioEngine?.prepare()
            try audioEngine?.start()
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
            
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
            stopRecording()
        }
    }

    public func stopRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        try? AVAudioSession.sharedInstance().setActive(false)
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength))
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedPower = max(-50, avgPower) // Limita o valor mínimo a -50 dB para visualização
        
        // Atualiza a amostra de som de forma assíncrona
        DispatchQueue.main.async {
            self.soundSamples[self.currentSample] = normalizedPower
            self.currentSample = (self.currentSample + 1) % self.numberOfSamples
        }
    }
}
