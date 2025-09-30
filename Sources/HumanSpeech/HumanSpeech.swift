// The Swift Programming Language
// https://docs.swift.org/swift-book


import Foundation
import AVFoundation
import Speech
import Observation

/**
 # HumanSpeech.SpeechRecognizer
 Helper para transcrever voz em texto usando `SFSpeechRecognizer` e `AVAudioEngine`.

 ## Visao geral
 Este tipo coordena permissao de microfone e reconhecimento de fala (locale "pt-BR"),
 inicia/paralisa captura de audio, e publica o texto transcrito em `transcript`.

 ## Disponibilidade
 - iOS 15+ (recomendado)
 - macOS 12+ (com microfone)

 ## Requisitos
 - Info.plist:
   - `NSSpeechRecognitionUsageDescription`
   - `NSMicrophoneUsageDescription`
 - Frameworks: `Speech`, `AVFoundation`

 ## Variaveis principais
 - `transcript`: String publicada com o texto parcial/final.
 - `audioEngine`: motor de audio em execucao.
 - `request`: fluxo de buffers de audio para o Speech.
 - `task`: tarefa de reconhecimento em andamento.
 - `recognizer`: reconhecedor configurado para "pt-BR".

 ## Metodos
 - `startTranscribing()`: inicia a transcricao continua.
 - `stopTranscribing()`: aguarda 1.5s e encerra a captura com limpeza.
 - `resetTranscript()`: limpa o texto e reseta estado interno.

 ## Como implementar (passo a passo)
 1. Crie uma instancia de `SpeechRecognizer`.
 2. Garanta as permissoes: a inicializacao solicita Speech e Microfone.
 3. Chame `startTranscribing()` para comecar.
 4. Observe `transcript` (MainActor) para atualizar sua UI.
 5. Para encerrar, chame `stopTranscribing()` (aguarda 1.5s antes de parar).
 6. Para limpar a UI, use `resetTranscript()`.

 ## Observacoes
 - `transcript` e atualizado no MainActor para manter a UI consistente.
 - Em caso de erro, `transcript` recebe uma mensagem entre `<< ... >>`.
 - `recognitionTask` usa `shouldReportPartialResults = true` para resultados parciais.
 - `actor` isola estado; handlers marcam metodos como `nonisolated` quando necessario.
 - Categoria de audio: `.playAndRecord` com `.duckOthers` para reduzir volumes de outros apps.

 ## Exemplo de uso (simples)
 ```swift
 @State private var texto = ""
 let sr = SpeechRecognizer()

 var body: some View {
   VStack {
     Text(texto)
     HStack {
       Button("Iniciar") { Task { await sr.startTranscribing() } }
       Button("Parar") { Task { await sr.stopTranscribing() } }
       Button("Limpar") { Task { await sr.resetTranscript() } }
     }
   }
   .task { for await t in sr.$transcript.values { texto = t } }
 }
 ```
 */

public actor SpeechRecognizer: Observable, ObservableObject {
    public enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        public var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    @MainActor @Published public var transcript: String = ""
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    /// Inicializa o reconhecedor (pt-BR) e solicita permissoes de fala e microfone.
    public init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
        guard recognizer != nil else {
            transcribe(RecognizerError.nilRecognizer)
            return
        }
        
        Task {
            do {
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                transcribe(error)
            }
        }
    }
    
    /// Inicia a transcricao continua.s.
    /// - Atualiza: `transcript` com string formatada do melhor reconhecimento.
    /// - Observacao: se ja existir uma task, ela sera substituida apos `reset()` interno no erro.
    @MainActor public func startTranscribing() {
        Task {
            await transcribe()
        }
    }
    
    /// Limpa `transcript` e reseta estado interno.
    /// - Efeitos: cancela task em andamento, para o audio e zera buffers.
    @MainActor public func resetTranscript() {
        Task {
            await reset()
            self.transcript = ""
        }
    }
    
    /// Encerra a transcricao com atraso controlado.
    /// - Importante: aguarda 1.5s antes de parar para nao cortar o final da fala.
    @MainActor public func stopTranscribing() {
        Task {
            // espera 1.5 segundos (1_500_000_000 nanossegundos)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await reset()
        }
    }
    
    /// Cria `request` e `recognitionTask` se o reconhecedor estiver disponivel.
    /// - Em erro: chama `reset()` e publica mensagem amigavel em `transcript`.
    private func transcribe() {
        guard let recognizer, recognizer.isAvailable else {
            self.transcribe(RecognizerError.recognizerIsUnavailable)
            return
        }
        
        do {
            let (audioEngine, request) = try Self.prepareEngine()
            self.audioEngine = audioEngine
            self.request = request
            self.task = recognizer.recognitionTask(with: request, resultHandler: { [weak self] result, error in
                self?.recognitionHandler(audioEngine: audioEngine, result: result, error: error)
            })
        } catch {
            self.reset()
            self.transcribe(error)
        }
    }
    
    /// Finaliza e limpa recursos de reconhecimento e audio.
    /// - Efeitos: `task.cancel()`, `audioEngine.stop()`, zera `request` e `task`.
    private func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }
    
    /// Configura `AVAudioEngine`, `AVAudioSession` e o tap de entrada; retorna (engine, request).
    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
    
    /// Trata resultados/erros da tarefa.
    /// - Se `isFinal` ou houver erro: para engine e remove o tap.
    /// - Encaminha `bestTranscription.formattedString` para `transcript`.
    nonisolated private func recognitionHandler(audioEngine: AVAudioEngine, result: SFSpeechRecognitionResult?, error: Error?) {
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError = error != nil
        
        if receivedFinalResult || receivedError {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        if let result {
            transcribe(result.bestTranscription.formattedString)
        }
    }
    
    /// Publica mensagem no MainActor em `transcript`.
    nonisolated private func transcribe(_ message: String) {
        Task { @MainActor in
            transcript = message
        }
    }
    
    /// Converte um erro em mensagem amigavel e publica em `transcript`.
    nonisolated private func transcribe(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        Task { @MainActor [errorMessage] in
            transcript = "<< \(errorMessage) >>"
        }
    }
}

extension SFSpeechRecognizer {
    /// Solicita ou consulta a autorizacao do sistema para reconhecimento de fala.
    /// - Retorno: `true` se autorizado, `false` caso contrario.
    /// - Observacao: o primeiro acesso pode abrir dialog de permissao.
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    /// Solicita ou consulta a permissao do sistema para gravar audio.
    /// - Retorno: `true` se autorizado, `false` se negado.
    /// - Observacao: o primeiro acesso pode abrir dialog de permissao.
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
