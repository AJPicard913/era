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
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    sectionCard(title: "Today's Sessions") {
                        metricRow(label: "Completed", value: "\(vm.todaysSessions)")
                        metricRow(label: "Daily Goal", value: vm.goalProgress)
                        Stepper("Goal: \(vm.dailyGoal)", value: Binding(
                            get: { vm.dailyGoal },
                            set: { vm.updateDailyGoal($0) }
                        ), in: 1...20)
                            .padding(.top, 4)
                    }

                    sectionCard(title: "Trends") {
                        metricRow(label: "This Week", value: "\(vm.weeklySessions)")
                        metricRow(label: "This Month", value: "\(vm.monthlySessions)")
                        metricRow(label: "Avg Time Between Sessions", value: vm.avgIntervalText)
                        metricRow(label: "Typical Time of Day", value: vm.dominantTimeOfDay)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") { vm.refresh() }
                }
            }
        }
        .onAppear { vm.refresh() }
    }

    private func sectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}