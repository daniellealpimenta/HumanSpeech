//
//  AudioStreamObserver.swift
//  HumanSpeech
//
//  Created by Daniel Leal PImenta on 26/09/25.
//


import CoreML
import SoundAnalysis
import AVFoundation
import SwiftUI
import Speech

@MainActor
public class AudioStreamObserver: NSObject, SNResultsObserving, ObservableObject {
    @Published public var currentSound: String = ""
   
    public nonisolated func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        guard let classification = result.classifications.first else { return }
        
        let identifier = classification.identifier
        
        Task { @MainActor in
            self.currentSound = identifier
        }
    }

   public nonisolated func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed: \(error.localizedDescription)")
    }
    
    public nonisolated func requestDidComplete(_ request: SNRequest) {
        print("Sound analysis request completed succesfully!")
    }
}
