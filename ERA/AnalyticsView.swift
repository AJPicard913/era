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
                            showsSparkline: false,
                            showsBars: true,
                            sparklinePoints: vm.weeklyTrendNormalized,
                            rawPoints: vm.weeklyTrendRaw
                        )
                        MetricCard(
                            valueText: nil,
                            metricLabel: "Breathing Sessions",
                            metricSubtitle: "This Month",
                            showsSparkline: false,
                            showsBars: true,
                            sparklinePoints: vm.monthlyTrendNormalized,
                            rawPoints: vm.monthlyTrendRaw
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
    var showsBars: Bool = false
    var sparklinePoints: [Double] = []
    var rawPoints: [Int] = []

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
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if showsBars {
                    BarChartInteractive(
                        normalizedPoints: sparklinePoints,
                        rawPoints: rawPoints
                    )
                    .padding(.top, 6)
                } else if showsSparkline {
                    SparklineInteractive(
                        normalizedPoints: sparklinePoints,
                        rawPoints: rawPoints
                    )
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
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

// MARK: - Interactive sparkline with drag-to-scrub and live value tooltip
private struct SparklineInteractive: View {
    var normalizedPoints: [Double]
    var rawPoints: [Int]
    var height: CGFloat = 56
    @State private var selectedIndex: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = geo.size.height
            let count = normalizedPoints.count
            let stepX = count > 1 ? w / CGFloat(count - 1) : w

            ZStack {
                SmoothSparkline(points: normalizedPoints)
                    .stroke(
                        LinearGradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                if let idx = selectedIndex, idx >= 0, idx < count {
                    let clampedNorm = max(0, min(1, normalizedPoints[idx]))
                    let x = CGFloat(idx) * stepX
                    let y = (1 - clampedNorm) * h
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }
                    .stroke(Color.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                        .frame(width: 10, height: 10)
                        .position(x: x, y: y)

                    let value = (idx < rawPoints.count) ? rawPoints[idx] : 0
                    Text("\(value)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThickMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                        .position(
                            x: min(max(30, x), w - 30),
                            y: max(12, y - 18)
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard count > 0 else { return }
                        let x = min(max(0, value.location.x), w)
                        let idx = Int(round(x / max(stepX, 0.0001)))
                        selectedIndex = min(max(0, idx), max(0, count - 1))
                    }
                    .onEnded { _ in
                        selectedIndex = nil
                    }
            )
        }
        .frame(height: height)
    }
}

private struct SmoothSparkline: Shape {
    var points: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let stepX = rect.width / CGFloat(max(points.count - 1, 1))
        let ys = points.map { 1 - max(0, min(1, $0)) }
        let pts: [CGPoint] = ys.enumerated().map { i, y in
            CGPoint(x: CGFloat(i) * stepX, y: CGFloat(y) * rect.height)
        }

        path.move(to: pts[0])

        if pts.count == 2 {
            path.addLine(to: pts[1])
            return path
        }

        let tension: CGFloat = 0.5 // 0...1 (higher = tighter curves)

        for i in 0..<(pts.count - 1) {
            let p0 = i > 0 ? pts[i - 1] : pts[i]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = (i + 2 < pts.count) ? pts[i + 2] : pts[i + 1]

            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * (tension / 6.0),
                y: p1.y + (p2.y - p0.y) * (tension / 6.0)
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * (tension / 6.0),
                y: p2.y - (p3.y - p1.y) * (tension / 6.0)
            )

            path.addCurve(to: p2, control1: c1, control2: c2)
        }

        return path
    }
}

// MARK: - Interactive bar chart (drag to scrub) with gradient bars
private struct BarChartInteractive: View {
    var normalizedPoints: [Double]
    var rawPoints: [Int]
    var height: CGFloat = 64
    @State private var selectedIndex: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = geo.size.height
            let count = max(1, normalizedPoints.count)
            let stepX = w / CGFloat(count)
            let barWidth = max(2, stepX * 0.6)

            ZStack {
                // Bars
                HStack(alignment: .bottom, spacing: stepX - barWidth) {
                    ForEach(0..<count, id: \.self) { i in
                        let norm = max(0, min(1, i < normalizedPoints.count ? normalizedPoints[i] : 0))
                        let barH = norm * h
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: barWidth, height: max(2, barH))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.black.opacity(selectedIndex == i ? 0.25 : 0.08), lineWidth: selectedIndex == i ? 1 : 0.5)
                            )
                            .opacity(selectedIndex == nil || selectedIndex == i ? 1.0 : 0.45)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                // Selection highlight + tooltip
                if let idx = selectedIndex, idx >= 0, idx < count {
                    let norm = max(0, min(1, normalizedPoints[idx]))
                    let x = min(max(CGFloat(idx) * stepX + barWidth/2, 0), w)
                    let y = (1 - norm) * h

                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }
                    .stroke(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    let value = idx < rawPoints.count ? rawPoints[idx] : 0
                    Text("\(value)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThickMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                        .position(
                            x: min(max(30, x), w - 30),
                            y: max(12, y - 18)
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = min(max(0, value.location.x), w)
                        let idx = Int(floor(x / max(stepX, 0.0001)))
                        selectedIndex = min(max(0, idx), max(0, count - 1))
                    }
                    .onEnded { _ in
                        selectedIndex = nil
                    }
            )
        }
        .frame(height: height)
    }
}