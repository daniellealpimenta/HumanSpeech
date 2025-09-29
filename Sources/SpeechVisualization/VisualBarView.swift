//
//  VisualBarView.swift
//  HumanSpeech
//
//  Created by Daniel Leal PImenta on 29/09/25.
//

import SwiftUI

public struct VisualBarView: View {
    
    var value: CGFloat
    let numberOfSamples: Int = 30
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .top, endPoint: .bottom))
                .frame(width: UIScreen.main.bounds.width - CGFloat(numberOfSamples) * 10 / CGFloat(numberOfSamples), height: value)
        }
    }
}
