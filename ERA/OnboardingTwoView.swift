//
//  OnboardingTwoView.swift
//  ERA
//
//  Created by AJ Picard on 8/29/25.
//

import SwiftUI
import UIKit

struct OnboardingTwoView: View {
    var onFinished: (() -> Void)? = nil

    // Rings: center first → outermost last
    private let sizes: [CGFloat] = [44, 64, 86, 108]   // tweak to match your design
    private let opacities: [Double] = [0.70, 0.5, 0.3, 0.15]

    @State private var ringScales: [CGFloat] = [0.01, 0.01, 0.01, 0.01]
    @State private var groupScale: CGFloat = 1.0
    @State private var showSentence: Bool = false
    @State private var slideDown: Bool = false

    // Typewriter
    private let staticPrefix = "Era’s "
    private let typedRemainder = "want to help you focusing on your breathing through out your day."
    @State private var typed = ""

    var body: some View {
        VStack(alignment: .leading) {
            Spacer().frame(height: 120)

            ZStack {
                ForEach(sizes.indices, id: \.self) { i in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "CBAACB", opacity: opacities[i]),
                                         Color(hex: "FFB5A7", opacity: opacities[i])],
                                startPoint: .center, endPoint: .bottom
                            )
                        )
                        .frame(width: sizes[i], height: sizes[i])
                        .scaleEffect(ringScales[i])
                        .zIndex(Double(-i))
                }
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(groupScale)
            .frame(height: 220)

            Spacer().frame(height: 50)

            // “Era’s ” gradient + typed remainder
            (
                Text(staticPrefix)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex:"CBAACB"), Color(hex:"FFB5A7")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                +
                Text(typed)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
            )
            .multilineTextAlignment(.leading)
            .lineSpacing(4)
            .padding(.horizontal, 24)
            .opacity(showSentence ? 1 : 0)
            

            Spacer().frame(height: 100)
        }
        .offset(y: slideDown ? UIScreen.main.bounds.height : 0)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear { Task { await runSequence() } }
    }

    // MARK: - Sequence
    private func runSequence() async {
        await animateRings()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await typeText()
    }

    private func animateRings() async {
        for i in 0..<ringScales.count {
            Task {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                    ringScales[i] = 1.1
                }
            }
        }
    }

    private func typeText() async {
        await MainActor.run {
            showSentence = true
            typed = ""
        }
        for ch in typedRemainder {
            await MainActor.run { typed.append(ch) }
            try? await Task.sleep(nanoseconds: 28_000_000)  // ~0.028s per character
        }
        // Wait 3 seconds, then slide the whole view down, then navigate to ContentView
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.55)) { slideDown = true }
        }
        try? await Task.sleep(nanoseconds: 550_000_000)
        await MainActor.run { onFinished?() }
    }
}
