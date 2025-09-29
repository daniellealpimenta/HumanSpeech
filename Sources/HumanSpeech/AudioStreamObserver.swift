//
//  AudioStreamObserver.swift
//  HumanSpeech
//
//  Created by Daniel Leal PImenta on 26/09/25.
//


import Foundation
import SoundAnalysis
import SwiftUI
import CoreML

// Observador exposto ao MainActor (estado @Published) mas que recebe callbacks
// do SoundAnalysis de threads quaisquer — por isso os métodos do protocolo são nonisolated + @objc.
@MainActor
public final class AudioStreamObserver: NSObject, SNResultsObserving, ObservableObject {
    @Published public var currentSound: String = ""

    public override init() {
        super.init()
    }

    // SoundAnalysis chama este método em threads arbitrárias.
    // Declaramos nonisolated + @objc para interoperabilidade ObjC + Swift concurrency.
    @objc public nonisolated func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let classification = result.classifications.first else { return }

        let identifier = classification.identifier

        // Volta para MainActor de forma segura e explícita.
        Task { @MainActor in
            self.currentSound = identifier
        }
    }

    @objc public nonisolated func request(_ request: SNRequest, didFailWithError error: Error) {
        // Apenas log: mantém nonisolated para compatibilidade com o framework.
        print("Sound analysis failed: \(error.localizedDescription)")
    }

    @objc public nonisolated func requestDidComplete(_ request: SNRequest) {
        print("Sound analysis request completed successfully!")
    }
}

