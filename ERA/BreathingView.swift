import SwiftUI
import CoreHaptics
import UIKit
import CoreData

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = effect }
}

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        var s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: UInt64
        switch s.count {
        case 3: (r,g,b) = ((v >> 8) * 17, (v >> 4 & 0xF) * 17, (v & 0xF) * 17)
        case 6: (r,g,b) = (v >> 16, v >> 8 & 0xFF, v & 0xFF)
        default: (r,g,b) = (0,0,0)
        }
        self = Color(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: opacity)
    }
}

struct BreathingView: View {
    enum Phase { case inhale, hold, exhale, done }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    // State machine
    @State private var phase: Phase = .inhale
    @State private var progress: Double = 0.0

    // UI states
    @State private var buttonAtTop = false
    @State private var buttonScale: CGFloat = 1.0

    // HOLD sine animator
    @State private var holdAnimProgress: Double = 0.0

    // Finished overlay state
    @State private var showFinish = false
    @State private var showFinishHeader = false
    @State private var showFinishCard = false
    @State private var showFinishClose = false
    @State private var factText: String = ""

    // Session tracking
    @State private var sessionStartDate: Date = Date()

    private let facts: [String] = [
        "Slow breathing can improve your mood and emotional regulation.",
        "Box breathing lowers heart rate and blood pressure within minutes.",
        "Deep nasal breathing boosts nitric oxide, aiding circulation.",
        "Long exhales activate the parasympathetic (rest-and-digest) system.",
        "Paced breathing can reduce perceived pain and anxiety.",
        "Even 5 minutes of slow, mindful breathing can sharpen focus and attention.",
        "Coherent breathing (~5–6 breaths/min) balances HRV.",
        "Mindful breathing can improve sleep quality.",
        "Longer exhales activate your parasympathetic \"rest and digest\" system, helping the body settle.",
        "Breathing through your nose filters, warms, and humidifies air—and also boosts nitric oxide, which supports oxygen delivery.",
        "About 5–6 breaths per minute (\"coherent breathing\") can increase heart-rate variability, a marker of relaxation.",
        "Your heart rate naturally rises on the inhale and falls on the exhale—this rhythm is called respiratory sinus arrhythmia.",
        "Diaphragmatic (belly) breathing does most of the work at rest and can reduce neck and shoulder tension from shallow chest breathing.",
        "Extending the exhale (e.g., inhale 4, exhale 6) often calms the nervous system more quickly than equal counts.",
        "A few minutes of slow, mindful breathing can lower perceived stress and improve focus.",
        "Box breathing (inhale–hold–exhale–hold for equal counts) is a simple pattern many people use to steady nerves.",
        "Consistent daily breath practice may improve sleep quality and make it easier to unwind at night.",
        "Upright posture gives your diaphragm room to move—slouching can make breaths shallower and less efficient."
    ]

    // Haptics
    @State private var hapticEngine: CHHapticEngine?

    // Timings
    private let inhaleDuration: Double = 4.0
    private let holdDuration:   Double = 2.0
    private let exhaleDuration: Double = 4.0
    private let phaseGap:       Double = 1.0

    // HOLD pulse params
    private let holdAmplitude: Double = 0.06
    private let holdCycles:    Double = 2.0

    // Lifecycle guards
    @State private var started = false
    @State private var sequenceTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Circles (now starting further off-screen)
            ZStack {
                circleLayer(sizeFrom: 150, sizeTo: UIScreen.main.bounds.width * 2.5,
                            yFrom: 200, yTo: -UIScreen.main.bounds.height * 0.3,
                            back: true)
                circleLayer(sizeFrom: 120, sizeTo: UIScreen.main.bounds.width * 2.0,
                            yFrom: 180, yTo: -UIScreen.main.bounds.height * 0.2)
                circleLayer(sizeFrom: 90,  sizeTo: UIScreen.main.bounds.width * 1.5,
                            yFrom: 160, yTo: -UIScreen.main.bounds.height * 0.1)
            }
            .scaleEffect(phase == .hold
                         ? 1.0 + CGFloat(holdAmplitude * sin(holdAnimProgress * .pi * 2.0 * holdCycles))
                         : 1.0)

            // Button (now positioned further down when active)
            Button(action: { /* no “Done” action */ }) {
                Text(buttonTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .contentTransition(.interpolate)
                    .background(VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial)).opacity(0.7))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(
                            LinearGradient(colors: [Color(hex:"CBAACB", opacity:0.7), Color(hex:"FFB5A7", opacity:0.7)],
                                           startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1
                        )
                    )
            }
            .scaleEffect(buttonScale)
            .padding(.horizontal, 50)
            .position(x: UIScreen.main.bounds.width / 2,
                      y: buttonAtTop ? 110 : -120) // Moved down from 60 to 110
            .opacity(buttonAtTop ? 1 : 0)
            .animation(.interpolatingSpring(stiffness: 110, damping: 12), value: buttonAtTop)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: buttonScale)
            .animation(.easeInOut(duration: 0.18), value: buttonTitle)

            // Finished overlay
            if showFinish {
                finishOverlay
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // Start once, lazily, when the view appears (instead of .task).
        .onAppear {
            guard !started else { return }
            started = true
            sequenceTask = Task { await startSequenceSafely() }
        }
        .onDisappear {
            sequenceTask?.cancel()
            sequenceTask = nil
            stopHaptics()
        }
       
    }
    

    private var buttonTitle: String {
        switch phase {
        case .inhale: return "Breathe In"
        case .hold:   return "Hold Breath"
        case .exhale: return "Breathe Out"
        case .done:   return "Done"
        }
    }

    // MARK: - Safe boot sequence
    private func startSequenceSafely() async {
        await prepareHaptics()
        // Small delay to let layout settle
        try? await Task.sleep(nanoseconds: 200_000_000)
        await MainActor.run { buttonAtTop = true }
        await runSequence()
    }

    // MARK: - Sequence (unchanged logic)
    private func runSequence() async {
        sessionStartDate = Date()

        phase = .inhale
        await animateInhaleBeats(totalDuration: inhaleDuration)

        phase = .hold
        await bounceButtonWithHaptic()
        try? await Task.sleep(nanoseconds: UInt64(phaseGap * 1_000_000_000))
        await runHoldSine(for: holdDuration)

        phase = .exhale
        await bounceButtonWithHaptic()
        try? await Task.sleep(nanoseconds: UInt64(phaseGap * 1_000_000_000))
        await animateExhaleBeats(totalDuration: exhaleDuration)

        await MainActor.run { buttonAtTop = false }
        await presentFinishedOverlay()
    }

    // MARK: - Save session (unchanged)
    private func saveBreathingSession() {
        let end = Date()
        let session = BreathingSession(context: viewContext)
        session.setValue(UUID(), forKey: "id")
        session.setValue(sessionStartDate, forKey: "startedAt")
        session.setValue(end, forKey: "endedAt")
        do { try viewContext.save() } catch { print("Failed to save breathing session: \(error)") }
    }

    // MARK: - Inhale beats (smooth 3-keyframe pattern per second)
    private func animateInhaleBeats(totalDuration: Double) async {
        let beats = 4
        let beatDuration = totalDuration / Double(beats) // 1.0s
        for i in 0..<beats {
            let start = Double(i) / Double(beats)
            let end   = Double(i + 1) / Double(beats)
            
            // 1) smooth surge
            let p1 = start + 0.88 * (end - start)
            await MainActor.run {
                withAnimation(.timingCurve(0.22, 0.9, 0.36, 1.0, duration: beatDuration * 0.58)) {
                    progress = p1
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(beatDuration * 0.58 * 1_000_000_000))
            
            // 2) gentle retreat
            let p2 = start + 0.78 * (end - start)
            await MainActor.run {
                withAnimation(.easeInOut(duration: beatDuration * 0.14)) { progress = p2 }
            }
            try? await Task.sleep(nanoseconds: UInt64(beatDuration * 0.14 * 1_000_000_000))
            
            // 3) spring to end + haptic
            playHapticTransient()
            await MainActor.run {
                withAnimation(.interpolatingSpring(stiffness: 160, damping: 20)) { progress = end }
            }
            try? await Task.sleep(nanoseconds: UInt64(beatDuration * 0.28 * 1_000_000_000))
        }
    }
    
    // MARK: - Exhale beats (mirrored + smooth)
    private func animateExhaleBeats(totalDuration: Double) async {
        let beats = 4
        let beatDuration = totalDuration / Double(beats) // 1.0s
        for i in 0..<beats {
            let start = 1.0 - Double(i) / Double(beats)
            let end   = 1.0 - Double(i + 1) / Double(beats)
            
            // 1) smooth drop
            let p1 = start + 0.88 * (end - start)
            await MainActor.run {
                withAnimation(.timingCurve(0.4, 0.0, 0.6, 1.0, duration: beatDuration * 0.58)) {
                    progress = p1
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(beatDuration * 0.58 * 1_000_000_000))
            
            // 2) gentle rebound
            let p2 = start + 0.78 * (end - start)
            await MainActor.run {
                withAnimation(.easeInOut(duration: beatDuration * 0.14)) { progress = p2 }
            }
            try? await Task.sleep(nanoseconds: UInt64(beatDuration * 0.14 * 1_000_000_000))
            
            // 3) spring to end + haptic
            playHapticTransient()
            await MainActor.run {
                withAnimation(.interpolatingSpring(stiffness: 160, damping: 20)) { progress = end }
            }
            try? await Task.sleep(nanoseconds: UInt64(beatDuration * 0.28 * 1_000_000_000))
        }
    }
    
    // MARK: - HOLD (smooth sine pulse + optional haptics)
    private func runHoldSine(for duration: Double) async {
        // Animate sine driver 0→1 linearly over duration (smooth)
        await MainActor.run {
            holdAnimProgress = 0.0
            withAnimation(.linear(duration: duration)) { holdAnimProgress = 1.0 }
        }
        // Optional: soft ticks at 0.5s marks (4 total)
        async let ticks: Void = playHapticsEvery(secondCount: Int(duration / 0.5)) // 4 ticks
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        _ = await ticks
        await MainActor.run { holdAnimProgress = 0.0 } // reset to neutral
    }
    
    // MARK: - Button bounce + haptic (awaits so the 1s gap comes AFTER this)
    private func bounceButtonWithHaptic() async {
        await MainActor.run { buttonScale = 0.92 }
        playHapticTransient(intensity: 0.9, sharpness: 0.7)
        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { buttonScale = 1.0 }
        }
        // Let the spring read before we start the 1s gap in the sequence
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    // MARK: - Circles (updated to start further off-screen)
    @ViewBuilder
    private func circleLayer(sizeFrom: CGFloat, sizeTo: CGFloat, yFrom: CGFloat, yTo: CGFloat, back: Bool = false) -> some View {
        let opac: Double = back ? 0.3 : (sizeFrom == 120 ? 0.5 : 0.7)
        Circle()
            .fill(LinearGradient(colors: [Color(hex:"CBAACB", opacity: opac), Color(hex:"FFB5A7", opacity: opac)],
                                 startPoint: .center, endPoint: .bottom))
            .frame(
                width: interpolate(from: sizeFrom, to: sizeTo, progress: progress),
                height: interpolate(from: sizeFrom, to: sizeTo, progress: progress)
            )
            .position(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height + interpolate(from: yFrom, to: yTo, progress: progress)
            )
    }

    // MARK: - Haptics (safer)
    @MainActor
    private func prepareHaptics() async {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            // Restart if the engine stops (e.g., app goes to background)
            engine.stoppedHandler = { reason in
                // You can log the reason if needed
            }
            engine.resetHandler = { [weak engine] in
                // Try to restart on reset
                try? engine?.start()
            }
            try await engine.start()
            self.hapticEngine = engine
        } catch {
            print("Haptic engine creation/start failed: \(error)")
        }
    }

    private func stopHaptics() {
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
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
        } catch {
            print("Haptic transient failed: \(error)")
        }
    }

    private func playHapticsEvery(secondCount: Int) async {
        guard secondCount > 0 else { return }
        for _ in 0..<secondCount {
            try? await Task.sleep(nanoseconds: 500_000_000)
            playHapticTransient(intensity: 0.6, sharpness: 0.5)
        }
    }

    private func interpolate(from: CGFloat, to: CGFloat, progress: Double) -> CGFloat {
        from + CGFloat(progress) * (to - from)
    }

    // MARK: - Finished overlay (unchanged) + presentation sequence
    private var finishOverlay: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 50)
            VStack(alignment: .leading, spacing: 4) {
                Text("Session Finished")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(0.7)
                (
                    Text("Congrats! ")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(hex:"CBAACB"), Color(hex:"FFB5A7")],
                            startPoint: .leading, endPoint: .trailing))
                    +
                    Text("You’ve completed your breathing session.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(showFinishHeader ? 1 : 0)
            .offset(y: showFinishHeader ? 0 : -12)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showFinishHeader)

            Spacer().frame(height: 40)

            VStack(alignment: .leading, spacing: 10) {
                Text(factText)
                    .font(.body)
                    .foregroundColor(.black)
                Text("BREATHING FACT")
                    .font(.caption)
                    .foregroundColor(Color(hex: "FFB5A7"))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
            .opacity(showFinishCard ? 1 : 0)
            .offset(y: showFinishCard ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: showFinishCard)

            Spacer()

            Button {
                saveBreathingSession()
                dismiss()
            } label: {
                Text("Close")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(hex:"CBAACB"), Color(hex:"FFB5A7")],
                                startPoint: .leading, endPoint: .trailing))
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                    .blur(radius: 0.2)
            )
            .shadow(color: Color(hex:"FFB5A7").opacity(0.3), radius: 22, x: 0, y: 16)
            .padding(.bottom, 30)
            .opacity(showFinishClose ? 1 : 0)
            .offset(y: showFinishClose ? 0 : 16)
            .animation(.spring(response: 0.45, dampingFraction: 0.9), value: showFinishClose)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private func presentFinishedOverlay() async {
        await MainActor.run {
            factText = facts.randomElement() ?? facts.first!
            showFinish = true
        }
        try? await Task.sleep(nanoseconds: 120_000_000)
        await MainActor.run { showFinishHeader = true }
        try? await Task.sleep(nanoseconds: 180_000_000)
        await MainActor.run { showFinishCard = true }
        try? await Task.sleep(nanoseconds: 220_000_000)
        await MainActor.run { showFinishClose = true }
    }
}
