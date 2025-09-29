// The Swift Programming Language
// https://docs.swift.org/swift-book

// FONTES/HumanSpeech/HumanSpeechManager.swift

import Foundation
import AVFoundation
import SoundAnalysis
import Speech
import CoreML
import Combine

// O Observer que processa os resultados da classificação de som.
// Ele é mantido como uma classe separada para organizar melhor o código.
@MainActor
class ResultsObserver: NSObject, SNResultsObserving {
    // Usamos um 'Subject' do Combine para enviar os resultados de volta para o nosso gerenciador.
    var classificationSubject = PassthroughSubject<String, Error>()

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let classification = result.classifications.first else { return }

        // Envia a classificação com a maior confiança.
        classificationSubject.send(classification.identifier)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        classificationSubject.send(completion: .failure(error))
    }

    func requestDidComplete(_ request: SNRequest) {
        classificationSubject.send(completion: .finished)
    }
}

@MainActor
public class HumanSpeechManager: ObservableObject {
    // MARK: - Propriedades Públicas (para a UI)
    @Published public var isListening = false
    @Published public var classificationResult: String = "Aguardando..."
    @Published public var transcribedText: String = ""

    // MARK: - Componentes de Áudio e Análise
    private let audioEngine = AVAudioEngine()
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private let analysisQueue = DispatchQueue(label: "com.example.SoundAnalysisQueue")
    
    // MARK: - Componentes de Transcrição
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))! // Mude para sua localidade
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Modelo de ML
    private var classificationRequest: SNClassifySoundRequest
    
    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    private let resultsObserver = ResultsObserver()

    /// Inicializa o gerenciador com o seu modelo Core ML.
    /// - Parameter model: O modelo de classificação de som compilado (ex: HumanSpeaking().model).
    public init(model: MLModel) throws {
        // 1. Cria a requisição de classificação usando o modelo fornecido.
        self.classificationRequest = try SNClassifySoundRequest(mlModel: model)
        
        // 2. Observa os resultados vindos do ResultsObserver
        resultsObserver.classificationSubject
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.classificationResult = "Erro: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] newClassification in
                self?.handleClassification(newClassification)
            })
            .store(in: &cancellables)
    }

    /// Lida com uma nova classificação de som.
    private func handleClassification(_ newClassification: String) {
        self.classificationResult = newClassification
        
        // LÓGICA PRINCIPAL: Se for "Human", começa a transcrever. Senão, para.
        if newClassification.lowercased() == "human" {
            if recognitionTask == nil { // Inicia apenas se não estiver já transcrevendo
                startTranscription()
            }
        } else {
            stopTranscription()
        }
    }

    /// Pede as permissões necessárias para microfone e reconhecimento de fala.
    private func requestPermissions() async -> Bool {
        let hasMicrophoneAccess = await AVAudioSession.sharedInstance().requestRecordPermission()
        let speechAuthStatus = await SFSpeechRecognizer.requestAuthorization()
        
        return hasMicrophoneAccess && speechAuthStatus == .authorized
    }

    /// Inicia o processo de escuta e classificação.
    public func start() {
        Task {
            guard await requestPermissions() else {
                print("Erro: Permissões não concedidas.")
                self.classificationResult = "Permissões não concedidas."
                return
            }
            
            guard !isListening else { return }
            
            do {
                try startAudioEngine()
                isListening = true
                transcribedText = "" // Limpa o texto anterior
                classificationResult = "Escutando..."
            } catch {
                print("Erro ao iniciar o audio engine: \(error)")
                self.classificationResult = "Erro ao iniciar áudio."
            }
        }
    }

    /// Para o processo de escuta.
    public func stop() {
        guard isListening else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        streamAnalyzer?.removeAllRequests()
        stopTranscription() // Garante que a transcrição também pare
        
        isListening = false
        classificationResult = "Aguardando..."
    }
    
    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Configura o analisador de stream de áudio
        streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
        try streamAnalyzer!.add(classificationRequest, withObserver: resultsObserver)
        
        // Instala o 'tap' no microfone para capturar o áudio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            self?.analysisQueue.async {
                // Envia o buffer para a análise de som
                self?.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
                
                // Envia o mesmo buffer para a transcrição de fala (se estiver ativa)
                self?.recognitionRequest?.append(buffer)
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    // MARK: - Lógica de Transcrição
    
    private func startTranscription() {
        guard recognitionTask == nil else { return } // Previne múltiplas tarefas
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Não foi possível criar o SFSpeechAudioBufferRecognitionRequest")
        }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                self?.transcribedText = result.bestTranscription.formattedString
            }

            if error != nil || result?.isFinal == true {
                self?.stopTranscription()
            }
        }
    }

    private func stopTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
}
