// The Swift Programming Language
// https://docs.swift.org/swift-book

import CoreML
import SoundAnalysis
import AVFoundation
import SwiftUI
import Speech




//start
//stop
//verificar - feita
//transcrever
//reset?
@MainActor
public class HumanIdentiferManager: ObservableObject {
    
    //definindo nossas variáveis para o microfone e o sound analizys
    private var engine:           AVAudioEngine?
    private var inputBus:         AVAudioNodeBus?
    private var micInputFormat:   AVAudioFormat?
    private var streamAnalyzer:   SNAudioStreamAnalyzer?
    private var classifyRequest:  SNClassifySoundRequest?
    public var resultObserver =  AudioStreamObserver()
    

    let model = try? HumanSpeaking(configuration: MLModelConfiguration())
    
    
    init() {
        //Initializing the engine
        engine = AVAudioEngine()
            
        //Getting the built-in microphone audio bus and saving its format
        inputBus = AVAudioNodeBus(0)
            guard let inputBus = inputBus else {
            fatalError()
            }
        
        micInputFormat = engine?.inputNode.inputFormat(forBus: inputBus)
            
        guard let micInputFormat = micInputFormat else {
            fatalError("Could not retrieve microphone input format")
        }
        
        startEngine()
        //Initialiting sound stream analyzer with the microphone audio format
        streamAnalyzer = SNAudioStreamAnalyzer(format: micInputFormat)
        //Setup the custom sound classifier
        classifierSetup()

    }
    
     public func startEngine() {
            
            guard let engine = engine else {
                fatalError("Could not instantiate audio engine")
            }
            do {
                try engine.start()
            }
            catch {
                fatalError("Unable to start audio engine: \(error.localizedDescription)")
            }
            
        }
    
    public func classifierSetup() {
            let defaultConfig = MLModelConfiguration()
            let soundClassifier = try? HumanSpeaking(configuration: defaultConfig)
            
            guard let soundClassifier = soundClassifier else{
                fatalError("Could not instantiate sound classifier")
            }
            classifyRequest = try? SNClassifySoundRequest(mlModel: soundClassifier.model)
        }
    
    
    
    
    public func makeRequest(_ customModel: MLModel? = nil) throws -> SNClassifySoundRequest {
        // If applicable, create a request with a custom sound classification model
        
        if let model = self.model {
            let customRequest = try SNClassifySoundRequest(mlModel: model.model)
            return customRequest
        }
        
        fatalError("Couldn't create a request.")
    }
    
//    public func start() {
//        //começar a gravar
//        
//        
//    }
//    
//    public func stop() {
//        //parar de gravar
//    }

}
