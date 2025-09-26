// The Swift Programming Language
// https://docs.swift.org/swift-book

import CoreML
import SoundAnalysis
import AVFoundation
import SwiftUI
import Speech

@MainActor
class HumanIdentifierManager: NSObject, ObservableObject, SNResultsObserving {

    public var analyzer: SNAudioStreamAnalyzer!
    public let audioEngine = AVAudioEngine()
    public var inputFormat: AVAudioFormat!
    
    static let shared = HumanIdentifierManager()

    @Published var detectedSound: String = "Nenhum som detectado"

    override init() {
        super.init()

        inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        analyzer = SNAudioStreamAnalyzer(format: inputFormat)

        do {
            let model = try HumanSpeaking(configuration: MLModelConfiguration())
            let request = try SNClassifySoundRequest(mlModel: model.model)
            try analyzer.add(request, withObserver: self)
        } catch {
            print("ERRO AO CARREGAR MODELO")
        }
    }

    func start() {
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) {
            buffer, time in
            self.analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
        }

        do {
            try audioEngine.start()
        } catch {
            print("Erro ao iniciar áudio: (error)")
        }
    }

    nonisolated func request(_ request: SNRequest, didProduce result: SNResult) {
        if let classificationResult = result as? SNClassificationResult,
           let classification = classificationResult.classifications.first {
            let identifier = classification.identifier
            DispatchQueue.main.async {
                self.detectedSound = "\(identifier) ((String(classification.confidence * 100))%)"
                print("SOM DETECTADO: (self.detectedSound)")
            }
        }
    }
}
