// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import AVFoundation
import SoundAnalysis
import CoreML
import SwiftUI

@MainActor
public final class HumanIdentiferManager: ObservableObject {
    // AV
    private let engine = AVAudioEngine()
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private var classifyRequest: SNClassifySoundRequest?

    // Observador: mantemos uma referência forte para que o analyzer possa chamar de volta.
    public let resultObserver = AudioStreamObserver()

    @Published public var isAnalyzing: Bool = false

    public init() {
        setupClassifier()
    }

    // MARK: - Start
    public func start() async {
        // evita reentrância
        guard !isAnalyzing else { return }

        // Permissão
        guard await checkMicrophonePermission() else {
            print("Permissão microfone negada.")
            return
        }

        // Configure AVAudioSession (importante antes de engine.start())
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.duckOthers, .defaultToSpeaker])
            try session.setMode(.measurement) // menor pós-processamento
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Erro configurando AVAudioSession: \(error.localizedDescription)")
            return
        }

        // Formato de entrada
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)

        // Cria o analyzer local e guarda referência
        let analyzer = SNAudioStreamAnalyzer(format: inputFormat)
        self.streamAnalyzer = analyzer

        guard let classifyRequest = self.classifyRequest else {
            print("classifyRequest não inicializado.")
            return
        }

        // Adiciona a request com o observer
        do {
            try analyzer.add(classifyRequest, withObserver: resultObserver)
        } catch {
            print("Erro ao adicionar classifyRequest: \(error.localizedDescription)")
            return
        }

        // Instala tap: captura `analyzer` (local) e chama analyze em background Task
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, time in
            Task(priority: .userInitiated) {
                analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }

        engine.prepare()
        do {
            try engine.start()
            isAnalyzing = true
        } catch {
            print("Erro ao iniciar engine: \(error.localizedDescription)")
            // se falhar, limpamos
            engine.inputNode.removeTap(onBus: 0)
            streamAnalyzer?.removeAllRequests()
            streamAnalyzer = nil
            // tentar desativar sessão
            try? AVAudioSession.sharedInstance().setActive(false, options: [])
        }
    }

    // MARK: - Stop
    public func stop() {
        guard isAnalyzing else { return }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)

        // Limpa analyzer e requests
        streamAnalyzer?.removeAllRequests()
        streamAnalyzer = nil

        // desativa sessão de áudio (opcional)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Erro ao desativar AVAudioSession: \(error.localizedDescription)")
        }

        isAnalyzing = false
    }

    // MARK: - Setup
    private func setupClassifier() {
        let defaultConfig = MLModelConfiguration()
        do {
            let model = try HumanSpeaking(configuration: defaultConfig)
            self.classifyRequest = try SNClassifySoundRequest(mlModel: model.model)
        } catch {
            fatalError("Não foi possível inicializar o modelo HumanSpeaking: \(error)")
        }
    }

    // MARK: - Permissão
    private func checkMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
