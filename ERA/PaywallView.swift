import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var pm: PurchaseManager
    @EnvironmentObject var access: AccessGate

    @State private var isRestoring = false

    // Animated Era icon rings (reuse ContentView values)
    private let ringSizes: [CGFloat] = [12, 20, 32, 44]
    private let ringOpacities: [Double] = [0.70, 0.5, 0.3, 0.15]
    @State private var ringScales: [CGFloat] = [0.01, 0.01, 0.01, 0.01]

    // Glowing CTA animation
    @State private var glowRotation: Angle = .degrees(0)

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        feature("Unlimited breathing sessions")
                        feature("Full analytics & insights")
                        feature("All future features included")
                    }
                    .padding(.horizontal, 20)

                    glowingCTA
                        .padding(.horizontal, 40)

                    Button {
                        Task { await restore() }
                    } label: {
                        HStack(spacing: 8) {
                            if isRestoring { ProgressView() }
                            Text(isRestoring ? "Restoring…" : "Restore Purchases")
                        }
                    }
                    .disabled(pm.isLoading || isRestoring)

                    if let err = pm.lastError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .onAppear {
                pm.fetchOfferings()
                animateRings()
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    glowRotation = .degrees(360)
                }
            }
            .onReceive(pm.$isPro) { pro in
                if pro { dismiss() }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: animated icon + in-content close button (never clipped)
            HStack {
                ZStack {
                    ForEach(ringSizes.indices, id: \.self) { i in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "CBAACB", opacity: ringOpacities[i]),
                                        Color(hex: "FFB5A7", opacity: ringOpacities[i])
                                    ],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: ringSizes[i], height: ringSizes[i])
                            .scaleEffect(ringScales[i])
                            .zIndex(Double(-i))
                    }
                }
                .frame(width: 44, height: 44)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
           

            // Title
            Text("Upgrade to Era Pro")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feature(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill").imageScale(.large)
            Text(text)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
    }

    private var glowingCTA: some View {
        ZStack {
            Capsule()
                .fill(Color.clear)
                .overlay(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "CBAACB"),
                            Color(hex: "FFB5A7"),
                            Color(hex: "CBAACB")
                        ]),
                        center: .center
                    )
                    .rotationEffect(glowRotation)
                    .mask(Capsule().stroke(lineWidth: 10))
                    .blur(radius: 8)
                    .opacity(0.6)
                )
                .allowsHitTesting(false)

            Button {
                Task { await pm.buyLifetime() }
            } label: {
                HStack {
                    if pm.isLoading { ProgressView() }
                    Text(pm.isPro ? "You're Pro" : (pm.isLoading ? "Processing…" : ctaTitle()))
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                }
                .padding()
                .frame(height: 60)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.black.opacity(0.74), lineWidth: 0.5)
                )
                .foregroundStyle(.white)
            }
            .disabled(pm.isLoading || pm.isPro)
        }
        .frame(height: 64)
        .shadow(color: Color(hex: "CBAACB").opacity(0.9), radius: 25, x: 0, y: 10)
        .padding(.top, 30)
    }

    private func ctaTitle() -> String {
        if let price = pm.lifetimePriceString {
            return "Buy Lifetime – \(price)"
        }
        return "Buy Lifetime"
    }

    private func animateRings() {
        for i in 0..<ringScales.count {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                ringScales[i] = 1.1
            }
        }
    }

    private func restore() async {
        isRestoring = true
        await pm.restore()
        isRestoring = false
        if pm.isPro {
            dismiss()
        }
    }
}

#Preview("Paywall (Pro)") {
    PaywallPreviewWrapper(isPro: true)
}
#Preview("Paywall (Free)") {
    PaywallPreviewWrapper(isPro: false)
}

private struct PaywallPreviewWrapper: View {
    @StateObject var pm = PurchaseManager()
    @StateObject var access = AccessGate()
    var isPro: Bool
    var body: some View {
        PaywallView()
            .environmentObject(pm)
            .environmentObject(access)
            .onAppear {
                pm.isPro = isPro
            }
    }
}
