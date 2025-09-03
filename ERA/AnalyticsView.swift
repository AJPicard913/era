import SwiftUI
import CoreData

struct AnalyticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: AnalyticsViewModel

    init(context: NSManagedObjectContext) {
        _vm = StateObject(wrappedValue: AnalyticsViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        // Row 1
                        MetricCard(
                            valueText: "\(vm.todaysSessions)",
                            metricLabel: "Breathing Sessions",
                            metricSubtitle: "Today",
                            showsSparkline: false
                        )
                        MetricCard(
                            valueText: "\(vm.totalMinutes)",
                            metricLabel: "Breathing Sessions",
                            metricSubtitle: "Total Minutes",
                            showsSparkline: false
                        )
                        // Row 2
                        MetricCard(
                            valueText: nil,
                            metricLabel: "Breathing Sessions",
                            metricSubtitle: "This Week",
                            showsSparkline: true,
                            sparklinePoints: vm.weeklyTrendNormalized
                        )
                        MetricCard(
                            valueText: nil,
                            metricLabel: "Breathing Sessions",
                            metricSubtitle: "This Month",
                            showsSparkline: true,
                            sparklinePoints: vm.monthlyTrendNormalized
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 120) // space for bottom button
                }
                
                // Bottom gradient Close button with glow
                VStack {
                    Spacer()
                    GlowingGradientButton(title: "Close") {
                        dismiss()
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Analytics")
        }
        .onAppear { vm.refresh() }
    }
}

// MARK: - Metric Card
private struct MetricCard: View {
    var valueText: String?
    var metricLabel: String
    var metricSubtitle: String
    var showsSparkline: Bool
    var sparklinePoints: [Double] = []

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .overlay(
            VStack(alignment: .leading, spacing: 10) {
                if let value = valueText {
                    // Big gradient number
                    Text(value)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .padding(.top, 6)
                } else if showsSparkline {
                    Sparkline(points: sparklinePoints)
                        .stroke(LinearGradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                               startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(height: 56)
                        .padding(.top, 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(metricLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(metricSubtitle)
                        .font(.footnote)
                        .foregroundColor(.primary)
                }
                .padding(.bottom, 6)
            }
            .padding(.horizontal, 12)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
        .frame(height: 120)
    }
}

// MARK: - Sparkline
private struct Sparkline: Shape {
    var points: [Double] // values normalized roughly 0...1
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard points.count > 1 else { return p }

        let stepX = rect.width / CGFloat(points.count - 1)
        let ys = points.map { 1 - max(0, min(1, $0)) } // invert y so higher values are higher visually

        var x: CGFloat = 0
        p.move(to: CGPoint(x: x, y: ys[0] * rect.height))
        for i in 1..<ys.count {
            x = CGFloat(i) * stepX
            let y = ys[i] * rect.height
            p.addLine(to: CGPoint(x: x, y: y))
        }
        return p
    }
}

// MARK: - Glowing Gradient Button
private struct GlowingGradientButton: View {
    var title: String
    var action: () -> Void
    @State private var glowRotation: Angle = .degrees(0)

    var body: some View {
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

            Button(action: action) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
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
            }
        }
        .frame(height: 60)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                glowRotation = .degrees(360)
            }
        }
    }
}