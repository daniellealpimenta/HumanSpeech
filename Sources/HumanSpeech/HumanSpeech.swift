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
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private var classifyRequest: SNClassifySoundRequest?

    public var resultObserver = AudioStreamObserver()
    @Published public var isAnalyzing = false
    
    public init() {
        setupClassifier()
    }
    
    // MARK: - Funções de Controle Público
    
    public func start() async {
            // Garante que não estamos tentando iniciar duas vezes.
            guard !isAnalyzing else { return }
            
            guard await checkMicrophonePermission() else {
                print("Permissão para usar o microfone foi negada.")
                return
            }
            
            // 1. O analisador é criado AQUI, como uma constante local.
            let inputFormat = engine.inputNode.outputFormat(forBus: 0)
            let analyzer = SNAudioStreamAnalyzer(format: inputFormat)
            
            // Guarda a referência na propriedade da classe para podermos parar depois.
            self.streamAnalyzer = analyzer
            
            guard let classifyRequest else { return }
            do {
                try analyzer.add(classifyRequest, withObserver: resultObserver)
            } catch {
                print("Erro ao adicionar a requisição de análise: \(error.localizedDescription)")
                return
            }
            
            // 2. O bloco 'installTap' captura a constante local 'analyzer', não a propriedade 'self.streamAnalyzer'.
            // Isso é seguro e não viola as regras do MainActor.
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
                print("Erro ao iniciar a engine de áudio: \(error.localizedDescription)")
            }
        }
    
    
    public func stop() {
            guard isAnalyzing else { return }
            
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            // Usa a referência que guardamos para limpar as requisições.
            streamAnalyzer?.removeAllRequests()
            streamAnalyzer = nil // Libera o objeto da memória.
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
