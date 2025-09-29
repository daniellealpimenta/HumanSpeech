// The Swift Programming Language
// https://docs.swift.org/swift-book

import CoreML
import SoundAnalysis
import AVFoundation
import SwiftUI

@MainActor
public class HumanIdentiferManager: ObservableObject {
    
    // Ferramentas de áudio. Agora com uma propriedade para o formato.
    private let engine = AVAudioEngine()
    private let streamAnalyzer: SNAudioStreamAnalyzer
    private let micInputFormat: AVAudioFormat // <- CORREÇÃO 1: Adicionamos esta propriedade
    private var classifyRequest: SNClassifySoundRequest?

    public var resultObserver = AudioStreamObserver()
    @Published public var isAnalyzing = false
    
    public init() {
        // PREPARAÇÃO: O init agora prepara as ferramentas e guarda o formato.
        
        // Pega o formato de áudio do microfone e guarda na nossa nova propriedade.
        self.micInputFormat = engine.inputNode.outputFormat(forBus: 0)
        
        // Cria o analisador de áudio com o formato que guardamos.
        self.streamAnalyzer = SNAudioStreamAnalyzer(format: micInputFormat)
        
        // Cria a requisição com o seu modelo de Machine Learning.
        setupClassifier()
    }
    
    // MARK: - Funções de Controle Público
    
    public func start() async {
        guard await checkMicrophonePermission() else {
            print("Permissão para usar o microfone foi negada.")
            return
        }
        
        guard let classifyRequest else { return }
        do {
            try streamAnalyzer.add(classifyRequest, withObserver: resultObserver)
        } catch {
            print("Erro ao adicionar a requisição de análise: \(error.localizedDescription)")
            return
        }
        
        // CORREÇÃO 1: Usamos a nossa propriedade `micInputFormat` aqui.
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: micInputFormat) { buffer, time in
            Task(priority: .userInitiated) {
                self.streamAnalyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }
        
        engine.prepare()
        do {
            try engine.start()
            isAnalyzing = true
        } catch {
            print("Erro ao iniciar a engine de áudio: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        streamAnalyzer.removeAllRequests()
        isAnalyzing = false
    }
    
    // MARK: - Funções de Configuração Privadas
    
    private func setupClassifier() {
        let defaultConfig = MLModelConfiguration()
        guard let model = try? HumanSpeaking(configuration: defaultConfig) else {
            fatalError("Não foi possível carregar o modelo HumanSpeaking.")
        }
        
        self.classifyRequest = try? SNClassifySoundRequest(mlModel: model.model)
    }
    
    // CORREÇÃO 2: A função agora usa 'withCheckedContinuation' para retornar um Bool.
    private func checkMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
