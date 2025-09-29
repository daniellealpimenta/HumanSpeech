// The Swift Programming Language
// https://docs.swift.org/swift-book

import AVFoundation
import Speech
import SoundAnalysis
import CoreML
import SwiftUI

public class ResultsObserver: NSObject, SNResultsObserving {
    @Binding var classificationResult: String
    
    public init(result: Binding<String>){
        _classificationResult = result
    }
    
    public func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        
        guard let classification = result.classifications.first else { return }
        
        let timeInSeconds = result.timeRange.start.seconds
        
        let formattedTime = String(format: "%.2f", timeInSeconds)
        print("Analysis result for audio at time: \(formattedTime)")
        
        let percent = classification.confidence * 100
        let percentString = String(format: "%.2f", percent)
        
        classificationResult = classificationResult + "Analysis result for audio at time: \(formattedTime), Confidence: \(percentString)% (\(classification.identifier). \n"
    }
    
    public func request(_ request: SNRequest, didFailWithError error: Error) {
        print("The analysis failed: \(error.localizedDescription)")
    }
    
    public func requestDidComplete(_ request: SNRequest) {
        print("Analysis complete.")
    }
    
}
