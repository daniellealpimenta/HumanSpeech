// The Swift Programming Language
// https://docs.swift.org/swift-book

import AVFoundation
import CoreML
import SoundAnalysis
import Speech
import SwiftUI

@MainActor
public class HumanidentifierManager: NSObject, ObservableObject,
    SNResultsObserving
{

    public let engine = AVAudioEngine()
    public var analyzer: SNAudioStreamAnalyzer?
    public var request: SNClassifySoundRequest?

    @Published public var detectedSound: String = "Nenhum som detectado"

    public override init() {
        super.init()
        // Carrega o modelo
        if let model = try? HumanSpeaking(configuration: MLModelConfiguration())
        {
            request = try? SNClassifySoundRequest(mlModel: model.model)
        }
    }

    public func start() {
        // Pede permissão rápida
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            guard granted else { return }
            DispatchQueue.main.async {
                self.setupAndStart()
            }
        }
    }

    public func setupAndStart() {
        let inputFormat = engine.inputNode.inputFormat(forBus: 0)
        guard let request = request else { return }

        analyzer = SNAudioStreamAnalyzer(format: inputFormat)
        try? analyzer?.add(request, withObserver: self)

        engine.inputNode.installTap(
            onBus: 0,
            bufferSize: 8192,
            format: inputFormat
        ) {
            buffer,
            time in
            self.analyzer?.analyze(
                buffer,
                atAudioFramePosition: time.sampleTime
            )
        }

        try? AVAudioSession.sharedInstance().setCategory(.record)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
    }

    // SNResultsObserving
    nonisolated public func request(
        _ request: SNRequest,
        didProduce result: SNResult
    ) {
        if let res = result as? SNClassificationResult,
            let top = res.classifications.first
        {

            // copia para valores thread-safe
            let identifier = top.identifier
            let confidence = top.confidence

            DispatchQueue.main.async { [weak self] in
                self?.detectedSound = "\(identifier) \(Int(confidence * 100))%"
            }
        }
    }

}

//@MainActor
//public class HumanIdentifierManager: NSObject, ObservableObject, SNResultsObserving {
//
//    public var analyzer: SNAudioStreamAnalyzer!
//    public let audioEngine = AVAudioEngine()
//    public var inputFormat: AVAudioFormat!
//
//    static let shared = HumanIdentifierManager()
//
//    @Published var detectedSound: String = "Nenhum som detectado"
//
//    public override init() {
//        super.init()
//
//        inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
//        analyzer = SNAudioStreamAnalyzer(format: inputFormat)
//
//        do {
//            let model = try HumanSpeaking(configuration: MLModelConfiguration())
//            let request = try SNClassifySoundRequest(mlModel: model.model)
//            try analyzer.add(request, withObserver: self)
//        } catch {
//            print("ERRO AO CARREGAR MODELO")
//        }
//    }
//
//    public func start() {
//        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) {
//            buffer, time in
//            self.analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
//        }
//
//        do {
//            try audioEngine.start()
//        } catch {
//            print("Erro ao iniciar áudio: (error)")
//        }
//    }
//
//    public nonisolated func request(_ request: SNRequest, didProduce result: SNResult) {
//        if let classificationResult = result as? SNClassificationResult,
//           let classification = classificationResult.classifications.first {
//            let identifier = classification.identifier
//            DispatchQueue.main.async {
//                self.detectedSound = "\(identifier) ((String(classification.confidence * 100))%)"
//                print("SOM DETECTADO: (self.detectedSound)")
//            }
//        }
//    }
//}
