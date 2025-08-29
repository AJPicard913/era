import SwiftUI
import CoreHaptics
import UIKit

// ───────────────────────────────────────────────────────────────────────────────
// Optional helpers you already use elsewhere
// ───────────────────────────────────────────────────────────────────────────────

struct OnboardingOneView: View {
    /// Call this when the 2-second hold after the pill finishes
    var onFinished: () -> Void

    // Animation driver (0 → STOP_PROGRESS)
    @State private var progress: Double = 0.0

    // Pill entrance
    @State private var showPill = false
    @State private var pillScale: CGFloat = 0.94

    // Button slide-in (mirrors your breathing button behavior)
    @State private var buttonAtBottom = false

    // Haptics
    @State private var hapticEngine: CHHapticEngine?

    // Timings (mirrors your inhale timing/feel)
    private let inhaleDuration: Double = 4.0
    private let beats = 4                  // 4 beats over 4s, like your inhale
    private let STOP_PROGRESS: Double = 0.60  // where the circles stop (tweak to match the mock)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Circles (same palette as your app)
            ZStack {
                circleLayer(sizeFrom: 150, sizeTo: UIScreen.main.bounds.width * 2.5,
                            yFrom: 220, yTo: -UIScreen.main.bounds.height * 0.30,
                            opacity: 0.30)
                circleLayer(sizeFrom: 120, sizeTo: UIScreen.main.bounds.width * 2.0,
                            yFrom: 200, yTo: -UIScreen.main.bounds.height * 0.20,
                            opacity: 0.50)
                circleLayer(sizeFrom:  90, sizeTo: UIScreen.main.bounds.width * 1.5,
                            yFrom: 180, yTo: -UIScreen.main.bounds.height * 0.10,
                            opacity: 0.70)
            }

            // “Welcome to Era” pill – slides up & bounces after the circles stop
            if showPill {
                Text("Welcome to Era")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .frame(height: 40)
                    .background(
                        VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                            .opacity(0.8)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                    )
                    .scaleEffect(pillScale)
                    .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 8)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        // subtle bounce
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            pillScale = 1.0
                        }
                        // handoff 2s after the pill is visible (ties timing to the actual appearance)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            animateOutAndFinish()
                        }
                    }
            }
        }
        .toolbar(.hidden, for: .navigationBar) // no back button
        .onAppear {
            prepareHaptics()
            runIntro()
        }
    }

    // MARK: - Animate the “inhale-like” beats but stop at STOP_PROGRESS
    private func runIntro() {
        let beatDuration = inhaleDuration / Double(beats)
        for i in 0..<beats {
            let start = Double(i) / Double(beats) * STOP_PROGRESS
            let end   = Double(i + 1) / Double(beats) * STOP_PROGRESS

            // 1) smooth surge
            DispatchQueue.main.asyncAfter(deadline: .now() + beatDuration * (Double(i) + 0.00)) {
                withAnimation(.timingCurve(0.22, 0.9, 0.36, 1.0, duration: beatDuration * 0.58)) {
                    progress = start + 0.88 * (end - start)
                }
            }
            // 2) gentle retreat
            DispatchQueue.main.asyncAfter(deadline: .now() + beatDuration * (Double(i) + 0.58)) {
                withAnimation(.easeInOut(duration: beatDuration * 0.14)) {
                    progress = start + 0.78 * (end - start)
                }
            }
            // 3) spring to end + haptic tick
            DispatchQueue.main.asyncAfter(deadline: .now() + beatDuration * (Double(i) + 0.72)) {
                playHapticTransient()
                withAnimation(.interpolatingSpring(stiffness: 160, damping: 20)) {
                    progress = end
                }
            }
        }

        // When the last beat lands (≈ inhaleDuration), show the pill.
        // The handoff is now scheduled from the pill's `.onAppear` so it's
        // tied to when the pill actually appears on screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + inhaleDuration + 0.05) {
            playHapticTransient(intensity: 0.9, sharpness: 0.7)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                showPill = true
            }
        }
    }

    /// Animate pill + circles off-screen, then hand off to OB2
    private func animateOutAndFinish() {
        // Haptic cue as we leave
        playHapticTransient(intensity: 0.6, sharpness: 0.5)

        // Pill slides/fades down using its .transition on removal
        withAnimation(.easeInOut(duration: 0.45)) {
            showPill = false
        }

        // Circles glide back down (progress → 0)
        withAnimation(.easeInOut(duration: 0.55)) {
            progress = 0.0
        }

        // After the out-animations complete, advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onFinished()
        }
    }

    // MARK: - Circles
    @ViewBuilder
    private func circleLayer(sizeFrom: CGFloat, sizeTo: CGFloat,
                             yFrom: CGFloat, yTo: CGFloat,
                             opacity: Double) -> some View {
        Circle()
            .fill(
                LinearGradient(colors: [
                    Color(hex: "CBAACB", opacity: opacity),
                    Color(hex: "FFB5A7", opacity: opacity)
                ], startPoint: .center, endPoint: .bottom)
            )
            .frame(
                width: interpolate(from: sizeFrom, to: sizeTo, progress: progress),
                height: interpolate(from: sizeFrom, to: sizeTo, progress: progress)
            )
            .position(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height + interpolate(from: yFrom, to: yTo, progress: progress)
            )
    }

    private func interpolate(from: CGFloat, to: CGFloat, progress: Double) -> CGFloat {
        from + CGFloat(progress) * (to - from)
    }

    // MARK: - Haptics (same transient you use elsewhere)
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch { print("Haptic engine start failed: \(error)") }
    }

    private func playHapticTransient(intensity: Float = 0.7, sharpness: Float = 0.5) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let ev = CHHapticEvent(eventType: .hapticTransient, parameters: [i, s], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [ev], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch { print("Haptic transient failed: \(error)") }
    }
}
