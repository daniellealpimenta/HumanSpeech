// The Swift Programming Language
// https://docs.swift.org/swift-book

import AVFoundation
import Speech

public class SpeechManager {
    
    public var isRecording: Bool = false
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioSession: AVAudioSession!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    public init() {
        
    }
    
    public func checkPermission() {
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    break
                default:
                    print("Speech não disponível.")
                }
            }
        }
    }
    
    public func start(completion: @escaping (String?) -> Void) {
        if isRecording {
            stopRecording()
        } else {
            startRecording(completion: completion)
        }
    }
    
    // Corrigido o erro de digitação de 'VoVoid' para 'Void'
    public func startRecording(completion: @escaping (String?) -> Void) {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            print("Speech não disponível")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest!.shouldReportPartialResults = true
        
        recognizer.recognitionTask(with: recognitionRequest!) { (result, error) in
            guard error == nil else {
                print("Error \(error!.localizedDescription)")
                return
            }
            guard let result = result else { return }
            
            if result.isFinal {
                completion(result.bestTranscription.formattedString)
            }
        }
        
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat, block: { (buffer, _) in
            self.recognitionRequest?.append(buffer)
        })
        
        audioEngine.prepare()
        
        do {
            audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .spokenAudio, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioEngine.start()
            isRecording = true // Atualiza o estado
        } catch {
            print(error)
        }
    }
    
    public func stopRecording() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if audioEngine != nil && audioEngine.isRunning {
             audioEngine.stop()
             inputNode.removeTap(onBus: 0)
        }
        
        try? audioSession?.setActive(false)
        audioSession = nil
        isRecording = false // Atualiza o estado
    }
}
